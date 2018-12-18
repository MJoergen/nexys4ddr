library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- Simple testbench for the Mandelbrot state machine
-- We start with the point -1+0.5i, i.e. cx = -1 and cy = 0.5
-- The expected sequence of points is then:
-- cnt |   x   |   y   |   x   |   y   
-- ----+-------+-------+-------+--------
--  0  | 00000 | 00000 |  0    |   0
--  1  | 30000 | 08000 | -1    |   0.5
--  2  | 3C000 | 38000 | -0.25 |  -0.5
--  3  | 2D000 | 0C000 | -1.19 |   0.75

entity mandelbrot_tb is
end entity mandelbrot_tb;

architecture simulation of mandelbrot_tb is

   signal clk    : std_logic;
   signal rst    : std_logic := '1';
   signal rst_d1 : std_logic := '1';
   signal rst_d2 : std_logic := '1';

   signal start : std_logic;
   signal cx    : std_logic_vector(17 downto 0);
   signal cy    : std_logic_vector(17 downto 0);
   signal x     : std_logic_vector(17 downto 0);
   signal y     : std_logic_vector(17 downto 0);
   signal cnt   : std_logic_vector( 9 downto 0);
   signal done  : std_logic;

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


   cx <= "11" & X"0000";   -- i.e. -1
   cy <= "00" & X"8000";   -- i.e. 0.5

   p_start : process
   begin
      start <= '0';
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

   i_mandelbrot : entity work.mandelbrot
      port map (
         clk_i   => clk,
         rst_i   => rst,
         start_i => start,
         cx_i    => cx,
         cy_i    => cy,
         x_o     => x,
         y_o     => y,
         cnt_o   => cnt,
         done_o  => done
      ); -- i_mandelbrot

end architecture simulation;

