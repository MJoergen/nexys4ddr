library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library unimacro;
use unimacro.vcomponents.all;

entity mandelbrot is
   port (
      clk_i : in std_logic;
      rst_i : in std_logic;
      x_i   : in std_logic_vector(17 downto 0);
      y_i   : in std_logic_vector(17 downto 0);
      cnt_o : out std_logic_vector(9 downto 0)
   );
end entity mandelbrot;

architecture rtl of mandelbrot is

   signal p : std_logic_vector(35 downto 0);

begin

   i_mult : mult_macro
   generic map (
      DEVICE  => "7SERIES",
      LATENCY => 2,
      WIDTH_A => 18,
      WIDTH_B => 18
   )
   port map (
      P   => p,     -- Output
      A   => x_i,   -- Input
      B   => y_i,   -- Input
      CE  => '1',
      CLK => clk_i,
      RST => rst_i
   ); -- i_mult

   cnt_o <= p(9 downto 0);

end architecture rtl;

