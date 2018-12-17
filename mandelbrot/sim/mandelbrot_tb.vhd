library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity mandelbrot_tb is
end entity mandelbrot_tb;

architecture simulation of mandelbrot_tb is

   signal clk    : std_logic;
   signal rst    : std_logic := '1';
   signal rst_d1 : std_logic := '1';
   signal rst_d2 : std_logic := '1';

   signal cx   : std_logic_vector(17 downto 0);
   signal cy   : std_logic_vector(17 downto 0);
   signal cnt  : std_logic_vector( 9 downto 0);
   signal done : std_logic;

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


   cx <= "01" & X"FFFF";
   cy <= "00" & X"0000";

   -------------------
   -- Instantiate DUT
   -------------------

   i_mandelbrot : entity work.mandelbrot
      port map (
         clk_i  => clk,
         rst_i  => rst,
         cx_i   => cx,
         cy_i   => cy,
         cnt_o  => cnt,
         done_o => done
      ); -- i_mandelbrot

end architecture simulation;

