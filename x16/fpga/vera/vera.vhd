library ieee;
use ieee.std_logic_1164.all;

-- This is the top level module of the VERA.
-- It generates a display with 640x480 pixels at 60 Hz refresh rate.

entity vera is
   generic (
      G_FONT_FILE : string                               -- File name with fonts.
   );
   port (
      clk_i     : in    std_logic;                       -- 25 MHz

      vga_hs_o  : out   std_logic;                       -- VGA
      vga_vs_o  : out   std_logic;
      vga_col_o : out   std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end vera;

architecture structural of vera is

begin

   vga_hs_o  <= '0';
   vga_vs_o  <= '0';
   vga_col_o <= (others => '0');

end architecture structural;

