library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This is a simple run-length-encoding compression algorithm
-- It receives data one byte at a time, and writes the output
-- to a two-byte wide fifo. This simplifies the desgin.

-- One existing bug is that if the last byte of the frame is
-- different from the preceding, then two writes to the fifo
-- is necessary. Therefore, the second write may happen during
-- the first byte of the next frame.
-- This will be a problem, if the next frame is only one byte long,
-- because then the two writes will collide.
-- To reproduce this bug therefore send a two-byte frame (two different bytes),
-- followed immediately in the next clock cycle by a one-byte frame.

entity compress is
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      in_ena_i    : in  std_logic;
      in_sof_i    : in  std_logic;
      in_eof_i    : in  std_logic;
      in_data_i   : in  std_logic_vector(7 downto 0);
      out_ena_o   : out std_logic;
      out_sof_o   : out std_logic;
      out_eof_o   : out std_logic;
      out_data_o  : out std_logic_vector(7 downto 0)
   );
end compress;

architecture Structural of compress is

   signal in_sof_d  : std_logic;
   signal in_eof_d  : std_logic;
   signal in_data_d : std_logic_vector(7 downto 0);

   signal fifo_wr_en    : std_logic;
   signal fifo_wr_data  : std_logic_vector(31 downto 0);
   signal fifo_rd_en    : std_logic;
   signal fifo_rd_data  : std_logic_vector(15 downto 0);
   signal fifo_rd_empty : std_logic;

   signal out_ena   : std_logic;
   signal out_sof   : std_logic;
   signal out_eof   : std_logic;
   signal out_eof_d : std_logic;
   signal out_data  : std_logic_vector(7 downto 0);

   signal fsm_sof : std_logic;
   signal fsm_eof : std_logic;
   signal fsm_cnt : std_logic_vector(7 downto 0);

begin

   -- Remember the last byte received.
   proc_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if in_ena_i = '1' then
            in_sof_d  <= in_sof_i;
            in_eof_d  <= in_eof_i;
            in_data_d <= in_data_i;
         end if;

         if rst_i = '1' then
            in_sof_d  <= '0';
            in_eof_d  <= '0';
            in_data_d <= (others => '0');
         end if;
      end if;
   end process proc_delay;

   -- The main state machine to control the compression.
   proc_input : process (clk_i)
      variable same_v : std_logic;
      variable lst_v  : std_logic_vector(2 downto 0);
   begin
      if rising_edge(clk_i) then
         fifo_wr_en   <= '0';
         fifo_wr_data(31 downto 26) <= (others => '0');
         fifo_wr_data(15 downto 10) <= (others => '0');
         fifo_wr_data(9)            <= '0'; -- Never EOF on first byte
         fifo_wr_data(24)           <= '0'; -- Never SOF on second byte

         -- This compares the received byte with the previous byte.
         -- Take care to avoid wrap-around of counter.
         -- This value is not used at SOF.
         same_v := '0';
         if in_data_d = in_data_i and fsm_cnt /= X"FF" then
            same_v := '1';
         end if;

         lst_v := in_sof_i & in_eof_i & same_v;

         if in_ena_i = '1' then
            case lst_v is
               when "000" =>
                  -- Middle of frame, different byte received.
                  fifo_wr_data(7 downto 0)   <= in_data_d;
                  fifo_wr_data(8)            <= fsm_sof;
                  fifo_wr_data(23 downto 16) <= fsm_cnt;
                  fifo_wr_data(25)           <= fsm_eof;
                  fifo_wr_en <= '1';
                  fsm_sof    <= '0';
                  fsm_eof    <= '0';
                  fsm_cnt    <= (others => '0');

               when "001" =>
                  -- Middle of frame, same byte received.
                  fsm_cnt <= fsm_cnt + 1;

               when "010" =>
                  -- End of frame, but last byte is different.
                  fifo_wr_data(7 downto 0)   <= in_data_d;
                  fifo_wr_data(8)            <= fsm_sof;
                  fifo_wr_data(23 downto 16) <= fsm_cnt;
                  fifo_wr_data(25)           <= '0';
                  fifo_wr_en <= '1';
                  fsm_sof    <= '0';
                  fsm_eof    <= '1';   -- Force write on next clock cycle.
                  fsm_cnt    <= (others => '0');

               when "011" =>
                  -- End of frame, and last byte is the same as previous.
                  fifo_wr_data(7 downto 0)   <= in_data_d;
                  fifo_wr_data(8)            <= fsm_sof;
                  fifo_wr_data(23 downto 16) <= fsm_cnt + 1;
                  fifo_wr_data(25)           <= '1';
                  fifo_wr_en <= '1';
                  fsm_sof    <= '0';
                  fsm_eof    <= '0';
                  fsm_cnt    <= (others => '0');

               when "100" | "101" =>
                  -- First byte of multi-byte frame doesn't lead to any writes.
                  fsm_cnt <= (others => '0');
                  fsm_sof <= '1';
                  fsm_eof <= '0';

               when "110" | "111" =>
                  -- Frame consists of a single byte only.
                  fifo_wr_data(7 downto 0)   <= in_data_i;
                  fifo_wr_data(8)            <= '1';
                  fifo_wr_data(23 downto 16) <= (others => '0');
                  fifo_wr_data(25)           <= '1';
                  fifo_wr_en <= '1';

               when others => null;
            end case;
         end if;

         -- This inserts an extra write after EOF, if the
         -- last byte of the frame was different from the previous.
         -- This will overwrite a write from the next frame, if it occurs.
         if fsm_eof = '1' then
            fifo_wr_data(7 downto 0)   <= in_data_d;
            fifo_wr_data(8)            <= '0';
            fifo_wr_data(23 downto 16) <= (others => '0');
            fifo_wr_data(25)           <= '1';
            fifo_wr_en <= '1';
            fsm_eof <= '0';
         end if;

         if rst_i = '1' then
            fifo_wr_en <= '0';
            fsm_cnt    <= (others => '0');
            fsm_sof    <= '0';
            fsm_eof    <= '0';
         end if;
      end if;
   end process proc_input;


   --------------------------
   -- Instantiate output FIFO
   --------------------------

   -- This converts the data stream from 16-bits to 8-bits.
   inst_fifo : entity work.fifo_width_change
   generic map (
      G_WRPORT_SIZE => 32,
      G_RDPORT_SIZE => 16
      )
   port map (
      wr_clk_i   => clk_i,
      wr_rst_i   => rst_i,
      rd_clk_i   => clk_i,
      rd_rst_i   => rst_i,

      wr_en_i    => fifo_wr_en,
      wr_data_i  => fifo_wr_data,
      rd_en_i    => fifo_rd_en,
      rd_data_o  => fifo_rd_data,
      rd_empty_o => fifo_rd_empty
      );

   -- Read from fifo
   -- Add extra empty cycle between frame. Not necessary, but
   -- simplifies debugging.
   fifo_rd_en <= '1' when fifo_rd_empty = '0' and (out_eof = '0' or out_eof_d = '1')
                 else '0';

   -- Drive output signals
   proc_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         out_ena  <= fifo_rd_en;
         out_sof  <= fifo_rd_data(8) and fifo_rd_en;
         out_eof  <= fifo_rd_data(9) and fifo_rd_en;
         out_data <= fifo_rd_data(7 downto 0);
         out_eof_d <= out_eof;

         if rst_i = '1' then
            out_ena   <= '0';
            out_sof   <= '0';
            out_eof   <= '0';
            out_eof_d <= '0';
         end if;
      end if;
   end process proc_out;

   out_ena_o  <= out_ena;
   out_sof_o  <= out_sof;
   out_eof_o  <= out_eof;
   out_data_o <= out_data;

end Structural;

