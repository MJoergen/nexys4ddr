library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is a simple run-length-encoding compression algorithm

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

   signal fifo_in  : std_logic_vector(15 downto 0);
   signal fifo_out : std_logic_vector(15 downto 0);
   signal fifo_out_sof  : std_logic;
   signal fifo_out_eof  : std_logic;
   signal fifo_out_data : std_logic_vector(7 downto 0);
   signal fifo_rden  : std_logic;
   signal fifo_empty : std_logic;

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, COUNT_ST, WRITE_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;
   signal fsm_sof : std_logic;
   signal fsm_eof : std_logic;

   signal cur_byte : std_logic_vector(7 downto 0);
   signal cur_cnt  : std_logic_vector(7 downto 0);

   signal out_ena   : std_logic;
   signal out_sof   : std_logic;
   signal out_eof   : std_logic;
   signal out_data  : std_logic_vector(7 downto 0);

begin

   -------------------------
   -- Instantiate input FIFO
   -- Note: This input fifo really doesn't need to be very big.
   -- Just a few bytes will suffice.
   -------------------------

   fifo_in(15 downto 10) <= "000000";
   fifo_in(9) <= in_sof_i;
   fifo_in(8) <= in_eof_i;
   fifo_in(7 downto 0) <= in_data_i;
   fifo_out_sof  <= fifo_out(9);
   fifo_out_eof  <= fifo_out(8);
   fifo_out_data <= fifo_out(7 downto 0);

   inst_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16
   )
   port map (
      wr_clk_i   => clk_i,
      wr_rst_i   => rst_i,
      wr_en_i    => in_ena_i,
      wr_data_i  => fifo_in,
      --
      rd_clk_i   => clk_i,
      rd_rst_i   => rst_i,
      rd_en_i    => fifo_rden,
      rd_data_o  => fifo_out,
      rd_empty_o => fifo_empty 
   );

   proc_fsm : process (clk_i)
   begin
      if rising_edge(clk_i) then
         out_ena   <= '0';
         out_sof   <= '0';
         out_eof   <= '0';

         case fsm_state is
            when IDLE_ST =>
               if fifo_empty = '0' then
                  assert fifo_out_sof = '1' report "Expected SOF" severity failure;
                  fsm_sof   <= '1';
                  cur_byte  <= fifo_out_data;
                  cur_cnt   <= (others => '0');
                  fsm_state <= COUNT_ST;
               end if;

            when COUNT_ST =>
               if fifo_empty = '0' then
                  if cur_byte = fifo_out_data and 
                     cur_cnt /= X"FF" and
                     fifo_out_eof = '0' then

                     cur_cnt   <= cur_cnt + 1;
                  else
                     out_ena   <= '1';
                     out_sof   <= fsm_sof;
                     out_eof   <= '0';
                     out_data  <= cur_cnt;

                     fsm_sof   <= '0';
                     fsm_eof   <= fifo_out_eof;
                     fsm_state <= WRITE_ST;
                  end if;
               end if;

            when WRITE_ST =>
               out_ena  <= '1';
               out_sof  <= '0';
               out_eof  <= fsm_eof;
               out_data <= cur_byte;

               cur_byte  <= fifo_out_data;
               cur_cnt   <= (others => '0');
               fsm_sof   <= '0';
               if fsm_eof = '0' then
                  fsm_state <= COUNT_ST;
               else
                  fsm_state <= IDLE_ST;
               end if;

         end case;

         if rst_i = '1' then
            out_ena   <= '0';
            fsm_state <= IDLE_ST;
         end if;
      end if;
   end process proc_fsm;

   fifo_rden <= '1' when fsm_state = COUNT_ST and fifo_empty = '0' else '0';

   out_ena_o  <= out_ena;
   out_sof_o  <= out_sof;
   out_eof_o  <= out_eof;
   out_data_o <= out_data;

end Structural;

