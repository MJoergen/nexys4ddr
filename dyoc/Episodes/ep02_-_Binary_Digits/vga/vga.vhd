library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module drives the VGA interface of the design.
-- The screen resolution generated is 640x480 @ 60 Hz,
-- with 256 colours.
-- This module expects an input clock rate of approximately
-- 25.175 MHz. It will work with a clock rate of 25.0 MHz.
--
-- The VGA output displays the eight binary digits in the
-- input signal digits_i.

entity vga is
   port (
      clk_i     : in  std_logic;

      digits_i  : in  std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)
   );
end vga;

architecture structural of vga is

   -- Pixel counters
   signal pix_x : std_logic_vector(9 downto 0);
   signal pix_y : std_logic_vector(9 downto 0);

begin
   
   --------------------------------------------------
   -- Instantiate pixel counters
   --------------------------------------------------

   pix_inst : entity work.pix
   port map (
      clk_i   => clk_i,
      pix_x_o => pix_x,
      pix_y_o => pix_y
   ); -- pix_inst


   --------------------------------------------------
   -- Instantiate digits generator
   --------------------------------------------------

   digits_inst : entity work.digits
   port map (
      clk_i     => clk_i,
      digits_i  => digits_i,
      pix_x_i   => pix_x,
      pix_y_i   => pix_y,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o
   ); -- digits_inst

end architecture structural;

