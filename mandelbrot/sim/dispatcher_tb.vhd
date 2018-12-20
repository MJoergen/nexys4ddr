library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity dispatcher_tb is
end entity dispatcher_tb;

architecture simulation of dispatcher_tb is

   signal clk     : std_logic;
   signal rst     : std_logic;
   signal start   : std_logic;
   signal startx  : std_logic_vector(17 downto 0);
   signal starty  : std_logic_vector(17 downto 0);
   signal stepx   : std_logic_vector(17 downto 0);
   signal stepy   : std_logic_vector(17 downto 0);
   signal wr_addr : std_logic_vector(19 downto 0);
   signal wr_data : std_logic_vector( 8 downto 0);
   signal wr_en   : std_logic;
   signal done    : std_logic;

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
      start  <= '0';
      startx <= "01" & X"0000";  -- -1
      starty <= "01" & X"0000";  -- -1
      stepx  <= "00" & X"2000";  -- 0.125
      stepy  <= "00" & X"2000";  -- 0.125

      wait for 500 ns;
      wait until clk = '1';
      start <= '1';
      wait until clk = '1';
      start <= '0';
      wait;
   end process p_start;


   -------------------
   -- Instantiate DUT
   -------------------

   i_dispatcher : entity work.dispatcher
      generic map (
         G_MAX_COUNT     => 20,
         G_NUM_ROWS      => 10,
         G_NUM_COLS      => 10,
         G_NUM_ITERATORS => 3
      )
      port map (
         clk_i     => clk,
         rst_i     => rst,
         start_i   => start,
         startx_i  => startx,
         starty_i  => starty,
         stepx_i   => stepx,
         stepy_i   => stepy,
         wr_addr_o => wr_addr,
         wr_data_o => wr_data,
         wr_en_o   => wr_en,
         done_o    => done
      ); -- i_dispatcher

end architecture simulation;

