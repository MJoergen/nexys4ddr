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

   signal x   : std_logic_vector(17 downto 0);
   signal y   : std_logic_vector(17 downto 0);
   signal cnt : std_logic_vector( 9 downto 0);

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

   p_xy : process (clk)
   begin
      if rising_edge(clk) then
         x <= x + 1;
         y <= y + 1;

         if rst_d2 = '1' then
            x <= to_std_logic_vector(0, 18);
            y <= to_std_logic_vector(1, 18);
         end if;

         rst_d1 <= rst;
         rst_d2 <= rst_d1;
      end if;
   end process p_xy;


   -------------------
   -- Instantiate DUT
   -------------------

   i_mandelbrot : entity work.mandelbrot
      port map (
         clk_i => clk,
         rst_i => rst,
         x_i   => x,
         y_i   => y,
         cnt_o => cnt
      ); -- i_mandelbrot

end architecture simulation;

