library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module strips the incoming frame of the MAC CRC (the last four bytes)
-- This module operates in a store-and-forward mode,
-- where the entire frame is stored in the FIFO, until the last byte is received.
-- Only valid frames are forwarded. In other words, errored frames are discarded.
-- Frame data is stored in a special-purpose FIFO, and the write pointer of
-- the SOF is stored in a separate FIFO. If the frame is to be discarded, the write pointer is reset
-- to the start of the errored frame.
-- For simplicity, everything is in the same clock domain.

-- There is no flow control.

entity strip_crc is
   port (
      -- Input interface
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      rx_valid_i  : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);
      rx_last_i   : in  std_logic;
      rx_ok_i     : in  std_logic;  -- Only valid @ LAST

      -- Output interface
      out_valid_o : out std_logic;
      out_data_o  : out std_logic_vector(7 downto 0);
      out_last_o  : out std_logic
   );
end strip_crc;

architecture Structural of strip_crc is

   -- The size of the input buffer is 2K. This fits nicely in a single BRAM.
   constant C_ADDR_SIZE : integer := 11;
   type t_buf is array (0 to 2**C_ADDR_SIZE-1) of std_logic_vector(7 downto 0);
   signal rx_buf : t_buf := (others => (others => '0'));

   -- Current write pointer.
   signal wrptr       : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   -- Start of current frame.
   signal start_ptr   : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   -- Start of current frame.
   signal end_ptr     : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   -- Current read pointer.
   signal rdptr       : std_logic_vector(C_ADDR_SIZE-1 downto 0) := (others => '0');

   signal fifo_wren   : std_logic;
   signal fifo_wrdata : std_logic_vector(15 downto 0);
   signal fifo_rden   : std_logic;
   signal fifo_rddata : std_logic_vector(15 downto 0);
   signal fifo_empty  : std_logic;

   type t_fsm_state is (IDLE_ST, FWD_ST);
   signal fsm_state   : t_fsm_state := IDLE_ST;

   signal out_valid   : std_logic;
   signal out_last    : std_logic;
   signal out_data    : std_logic_vector(7 downto 0);

begin

   i_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16
   )
   port map (
      wr_clk_i    => clk_i,
      wr_rst_i    => rst_i,
      wr_en_i     => fifo_wren,
      wr_data_i   => fifo_wrdata,
      --
      rd_clk_i    => clk_i,
      rd_rst_i    => rst_i,
      rd_en_i     => fifo_rden,
      rd_data_o   => fifo_rddata,
      rd_empty_o  => fifo_empty,
      rd_error_o  => open           -- Read from empty fifo
   ); -- i_fifo


   proc_input : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fifo_wren   <= '0';
         fifo_wrdata <= (others => '0');

         if rx_valid_i = '1' then
            rx_buf(to_integer(wrptr)) <= rx_data_i;
            wrptr <= wrptr + 1;

            if rx_last_i = '1' then
               if rx_ok_i = '1' then
                  -- Prepare for next frame (and strip CRC).
                  start_ptr   <= wrptr-3;
                  wrptr       <= wrptr-3;
                  fifo_wrdata(C_ADDR_SIZE-1 downto 0) <= wrptr-4;
                  fifo_wren   <= '1';
               else
                  wrptr <= start_ptr;  -- Discard this frame.
               end if;
            end if;
         end if;

         if rst_i = '1' then
            start_ptr <= (others => '0');
            wrptr     <= (others => '0');
         end if;
      end if;
   end process proc_input;


   proc_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         fifo_rden <= '0';
         out_valid <= '0';
         out_last  <= '0';
         out_data  <= (others => '0');

         case fsm_state is
            when IDLE_ST =>
               if fifo_empty = '0' then
                  fifo_rden <= '1';
                  end_ptr   <= fifo_rddata(C_ADDR_SIZE-1 downto 0);
                  out_valid <= '1';
                  out_last  <= '0';
                  out_data  <= rx_buf(to_integer(rdptr));
                  rdptr     <= rdptr + 1;
                  fsm_state <= FWD_ST;
               end if;

            when FWD_ST =>
               out_valid <= '1';
               out_last  <= '0';
               out_data  <= rx_buf(to_integer(rdptr));
               rdptr     <= rdptr + 1;
               if rdptr = end_ptr then
                  out_last  <= '1';
                  fsm_state <= IDLE_ST;
               end if;

         end case;

         if rst_i = '1' then
            fsm_state <= IDLE_ST;
         end if;
      end if;
   end process proc_fsm;


   -- Drive output signals
   out_valid_o <= out_valid;
   out_last_o  <= out_last;
   out_data_o  <= out_data;

end Structural;

