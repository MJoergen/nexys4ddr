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
      rst_i     : in    std_logic;                       -- 25 MHz

      vga_hs_o  : out   std_logic;                       -- VGA
      vga_vs_o  : out   std_logic;
      vga_col_o : out   std_logic_vector(11 downto 0)    -- 4 bits for each colour RGB.
   );
end vera;

architecture structural of vera is

   signal pix_x_s : std_logic_vector(9 downto 0);
   signal pix_y_s : std_logic_vector(9 downto 0);

begin

   i_pix : entity work.pix
      generic map (
         G_PIX_X_COUNT => 800,
         G_PIX_Y_COUNT => 525
      )
      port map (
         clk_i   => clk_i,
         rst_i   => rst_i,
         pix_x_o => pix_x_s,
         pix_y_o => pix_y_s
      ); -- i_pix


   i_vga : entity work.vga
      port map (
         clk_i     => clk_i,
         rst_i     => rst_i,
         pix_x_i   => pix_x_s,
         pix_y_i   => pix_y_s,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vga

end architecture structural;

