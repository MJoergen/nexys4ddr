library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library unimacro;
use unimacro.vcomponents.all;

---------------------------
-- This module performs the following calculations:
-- new_x = (x+y)*(x-y) + cx
-- new_y = (2x)*y + cy
--
-- It does it by using a single multiplier in a pipeline fashion
-- Cycle 1 : Input to multiplier is (2x) and y.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y).

entity mandelbrot is
   port (
      clk_i : in std_logic;
      rst_i : in std_logic;
      cx_i  : in std_logic_vector(17 downto 0);
      cy_i  : in std_logic_vector(17 downto 0);
      cnt_o : out std_logic_vector(9 downto 0)
   );
end entity mandelbrot;

architecture rtl of mandelbrot is

   signal p : std_logic_vector(35 downto 0);
   signal x : std_logic_vector(17 downto 0);
   signal y : std_logic_vector(17 downto 0);

begin

   i_mult : mult_macro
   generic map (
      DEVICE  => "7SERIES",
      LATENCY => 2,
      WIDTH_A => 18,
      WIDTH_B => 18
   )
   port map (
      CLK => clk_i,
      RST => rst_i,
      CE  => '1',
      P   => p,     -- Output
      A   => x_i,   -- Input
      B   => y_i    -- Input
   ); -- i_mult

   cnt_o <= p(9 downto 0);

end architecture rtl;

