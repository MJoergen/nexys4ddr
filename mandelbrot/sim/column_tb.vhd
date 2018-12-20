library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity column_tb is
end entity column_tb;

architecture simulation of column_tb is

   signal clk         : std_logic;
   signal rst         : std_logic;
   signal job_start   : std_logic;
   signal job_cx      : std_logic_vector(17 downto 0);
   signal job_starty  : std_logic_vector(17 downto 0);
   signal job_stepy   : std_logic_vector(17 downto 0);
   signal job_done    : std_logic;
   signal res_addr    : std_logic_vector( 9 downto 0);
   signal res_ack     : std_logic;
   signal res_data    : std_logic_vector( 8 downto 0);
   signal res_valid   : std_logic;
   signal res_valid_d : std_logic;

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   p_start : process
   begin
      job_start  <= '0';
      job_cx     <= "11" & X"0000";     -- -1
      job_starty <= "11" & X"0000";     -- -1
      job_stepy  <= "00" & X"2000";     -- 0.125
      wait for 500 ns;
      wait until clk = '1';
      job_start <= '1';
      wait until clk = '1';
      job_start <= '0';
      wait;
   end process p_start;


   -------------------
   -- Instantiate DUT
   -------------------

   i_column : entity work.column
      generic map (
         G_MAX_COUNT => 20,
         G_NUM_ROWS  => 10
      )
      port map (
         clk_i        => clk,
         rst_i        => rst,
         job_start_i  => job_start,
         job_cx_i     => job_cx,
         job_starty_i => job_starty,
         job_stepy_i  => job_stepy,
         job_done_o   => job_done,
         res_addr_o   => res_addr,
         res_ack_i    => res_ack,
         res_data_o   => res_data,
         res_valid_o  => res_valid
      ); -- i_column


   p_res_ack : process (clk)
   begin
      if rising_edge(clk) then
         res_valid_d <= res_valid;
         res_ack     <= res_valid_d;
      end if;
   end process p_res_ack;


end architecture simulation;

