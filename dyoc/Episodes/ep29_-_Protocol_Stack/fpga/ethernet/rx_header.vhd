library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module prepends the frame with a two-byte header containing the total
-- number of bytes (excluding header) stored in little-endian format.
--
-- This module operates in a store-and-forward mode, where the entire frame is
-- stored in an input buffer, until the last byte is received.  Only valid
-- frames are forwarded. In other words, errored frames are discarded.  The
-- address of the last byte of the frame (EOF) is stored in a separate FIFO.
-- The address of the first byte of the frame is stored in the register
-- start_ptr.  If the frame is to be discarded, the current write pointer is
-- reset to this start_ptr.
--
-- For simplicity, everything is in the same clock domain.

entity rx_header is
   port (
      -- Input interface
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      rx_valid_i     : in  std_logic;
      rx_eof_i       : in  std_logic;
      rx_data_i      : in  std_logic_vector(7 downto 0);
      rx_error_i     : in  std_logic_vector(1 downto 0); -- Only valid @ EOF

      -- Statistics. All these counters saturate at their maximum value.
      cnt_good_o     : out std_logic_vector(15 downto 0);
      cnt_error_o    : out std_logic_vector( 7 downto 0);
      cnt_crc_bad_o  : out std_logic_vector( 7 downto 0);
      cnt_overflow_o : out std_logic_vector( 7 downto 0);

      -- Output interface
      out_afull_i    : in  std_logic;                    -- Output buffer is full.
      out_valid_o    : out std_logic;
      out_data_o     : out std_logic_vector(7 downto 0);
      out_eof_o      : out std_logic
   );
end rx_header;

architecture structural of rx_header is

   -- Input buffer overflow
   signal rx_error : std_logic := '0';

   -- Statistics
   signal cnt_good     : std_logic_vector(15 downto 0);
   signal cnt_error    : std_logic_vector( 7 downto 0);
   signal cnt_crc_bad  : std_logic_vector( 7 downto 0);
   signal cnt_overflow : std_logic_vector( 7 downto 0);

   -- Output interface
   signal out_valid : std_logic;
   signal out_data  : std_logic_vector(7 downto 0);
   signal out_eof   : std_logic;


   -- The size of the input buffer is 2K bytes. This fits nicely in a single BRAM.
   constant C_ADDR_SIZE : integer := 11;
   type t_buf is array (0 to 2**C_ADDR_SIZE-1) of std_logic_vector(7 downto 0);
   signal rx_buf : t_buf := (others => (others => '0'));

   -- Current write pointer.
   signal wrptr     : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');
   -- Start of current frame.
   signal start_ptr : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');
   -- End of current frame.
   signal end_ptr   : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');
   -- Current read pointer.
   signal rdptr     : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   -- Control fifo, contains address of each EOF.
   signal ctrl_wren   : std_logic;
   signal ctrl_wrdata : std_logic_vector(15 downto 0);
   signal ctrl_rden   : std_logic;
   signal ctrl_rddata : std_logic_vector(15 downto 0);
   signal ctrl_empty  : std_logic;

   -- State machine for header insertion.
   type t_fsm_state is (IDLE_ST, LEN_MSB_ST, FWD_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

begin

   -- This process collects statistics of the frames received.
   proc_stats : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid_i = '1' and rx_eof_i = '1' then
            if rx_error_i(0) = '1' then
               -- Receiver error
               if cnt_error /= X"FF" then     -- Saturate counter
                  cnt_error <= cnt_error + 1;
               end if;
            elsif rx_error_i(1) = '1' then
               -- CRC error
               if cnt_crc_bad /= X"FF" then   -- Saturate counter
                  cnt_crc_bad <= cnt_crc_bad + 1;
               end if;
            elsif rx_error = '1' then
               -- Buffer error
               if cnt_overflow /= X"FF" then   -- Saturate counter
                  cnt_overflow <= cnt_overflow + 1;
               end if;
            else
               -- No errors
               if cnt_good /= X"FFFF" then    -- Saturate counter
                  cnt_good <= cnt_good + 1;
               end if;
            end if;
         end if;

         if rst_i = '1' then
            cnt_good     <= (others => '0');
            cnt_error    <= (others => '0');
            cnt_crc_bad  <= (others => '0');
            cnt_overflow <= (others => '0');
         end if;
      end if;
   end process proc_stats;


   -- This process stores the incoming data in the input buffer,
   -- and stores the pointer to EOF in a separate control fifo.
   proc_input : process (clk_i)
   begin
      if rising_edge(clk_i) then
         ctrl_wren   <= '0';
         ctrl_wrdata <= (others => '0');

         if rx_valid_i = '1' then
            -- Check for buffer overflow or for oversize frame
            if wrptr + 1 = rdptr or (wrptr - start_ptr >= 1513 and rx_eof_i = '0') then
               -- Discard overflowed frame.
               rx_error <= '1';
            else
               -- Write data to buffer
               rx_buf(to_integer(wrptr)) <= rx_data_i;
               wrptr <= wrptr + 1;
            end if;

            if rx_eof_i = '1' then
               if rx_error_i = "00" and rx_error = '0' and wrptr+1 /= rdptr then
                  -- Prepare for next frame.
                  start_ptr   <= wrptr+1;
                  wrptr       <= wrptr+1;
                  -- Write the EOF address to control fifo
                  ctrl_wrdata(C_ADDR_SIZE-1 downto 0) <= wrptr;
                  ctrl_wren   <= '1';
               else
                  wrptr <= start_ptr;  -- Discard this frame.
               end if;
               rx_error <= '0';
            end if;
         end if;

         if rst_i = '1' then
            start_ptr <= (others => '0');
            wrptr     <= (others => '0');
            rx_error  <= '0';
         end if;
      end if;
   end process proc_input;


   -- Instantiate the control fifo to contain the address of each EOF.
   -- This fifo will contain one entry for each frame in the input buffer,
   -- so not very many entries in total. Therefore, we can safely ignore any
   -- write errors.
   inst_ctrl_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16
      )
   port map (
      wr_clk_i    => clk_i,
      wr_rst_i    => rst_i,
      wr_en_i     => ctrl_wren,
      wr_data_i   => ctrl_wrdata,
      wr_sb_i     => "00",
      wr_afull_o  => open,
      wr_error_o  => open,
      --
      rd_clk_i    => clk_i,
      rd_rst_i    => rst_i,
      rd_en_i     => ctrl_rden,
      rd_data_o   => ctrl_rddata,
      rd_sb_o     => open,
      rd_empty_o  => ctrl_empty,
      rd_error_o  => open
      );


   -- This process generates the output stream.
   proc_output : process (clk_i)
      variable frame_length_v : std_logic_vector(C_ADDR_SIZE-1 downto 0);
      variable end_ptr_v      : std_logic_vector(C_ADDR_SIZE-1 downto 0);
   begin
      if rising_edge(clk_i) then
         ctrl_rden <= '0';
         out_valid <= '0';
         out_data  <= (others => '0');
         out_eof   <= '0';

         if out_afull_i = '0' then  -- Pause, if receiver is not ready.
            case fsm_state is
               when IDLE_ST =>
                  if ctrl_empty = '0' then
                     end_ptr_v := ctrl_rddata(C_ADDR_SIZE-1 downto 0);
                     -- Calculate length excluding two-byte header.
                     -- 'rdptr' contains address of first byte.
                     -- 'end_ptr_v' contains address of last byte.
                     frame_length_v := end_ptr_v+1 - rdptr;

                     -- An entire frame is now ready.
                     ctrl_rden <= '1';
                     end_ptr   <= end_ptr_v;

                     -- Transfer LSB of length
                     out_valid <= '1';
                     out_data  <= frame_length_v(7 downto 0);
                     fsm_state <= LEN_MSB_ST;
                  end if;

               when LEN_MSB_ST =>
                  -- Transfer MSB of length
                  out_valid <= '1';
                  out_data(7 downto C_ADDR_SIZE-8) <= (others => '0');
                  out_data(C_ADDR_SIZE-9 downto 0) <= frame_length_v(C_ADDR_SIZE-1 downto 8);
                  fsm_state <= FWD_ST;

               when FWD_ST =>
                  -- Transfer frame data
                  out_valid <= '1';
                  out_data  <= rx_buf(to_integer(rdptr));
                  rdptr     <= rdptr + 1;
                  if rdptr = end_ptr then
                     out_eof   <= '1';
                     fsm_state <= IDLE_ST;
                  end if;
            end case;
         end if;

         if rst_i = '1' then
            fsm_state <= IDLE_ST;
         end if;
      end if;
   end process proc_output;


   -- Connect output signals
   out_valid_o    <= out_valid;
   out_data_o     <= out_data;
   out_eof_o      <= out_eof;

   cnt_good_o     <= cnt_good;
   cnt_error_o    <= cnt_error;
   cnt_crc_bad_o  <= cnt_crc_bad;
   cnt_overflow_o <= cnt_overflow;

end structural;

