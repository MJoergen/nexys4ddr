library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.font_pkg.all;

-- This module shows the frame rate (the same value as on the 7-segment
-- display) as an overlay in the top right corner of the VGA output. The
-- frame rate has G_DIGITS decimal digits, shown in white on a black
-- background with the 16x32 font in font_pkg.vhd. The digits are right
-- aligned, and the blanked (leading zero) digits are not shown, i.e. the
-- picture is shown there.
--
-- The frame rate is calculated in the MAIN clock domain (fps.vhd), and it is
-- moved to the VGA clock domain in the top level module, so fps_digits_i and
-- fps_blank_i are in the VGA clock domain. They may change at any time: the
-- value is copied before the first line of each frame, so a new value is shown
-- from the next frame on, and a frame never shows two different values.
--
-- The overlay is added to the output of disp.vhd, which is delayed by one
-- clock cycle (all of vga_hs_o, vga_vs_o and vga_col_o). The pixel counters
-- (vga_pix_x_i and vga_pix_y_i) are those of the pixel, which is at the input
-- (vga_col_d4_i) four clock cycles later.

entity overlay is
   generic (
      G_DIGITS : natural := 8;
      G_X      : natural;                     -- Left edge of the overlay
      G_Y      : natural := 8                 -- Top edge of the overlay
   );
   port (
      vga_clk_i     : in  std_logic;

      -- The frame rate (in the VGA clock domain), see fps.vhd
      fps_digits_i  : in  std_logic_vector(4*G_DIGITS-1 downto 0);
      fps_blank_i   : in  std_logic_vector(G_DIGITS-1 downto 0);

      vga_pix_x_i   : in  std_logic_vector(10 downto 0);
      vga_pix_y_i   : in  std_logic_vector(10 downto 0);
      vga_hs_d4_i   : in  std_logic;
      vga_vs_d4_i   : in  std_logic;
      vga_col_d4_i  : in  std_logic_vector(7 downto 0);

      vga_hs_o      : out std_logic;
      vga_vs_o      : out std_logic;
      vga_col_o     : out std_logic_vector(7 downto 0)
   );
end entity overlay;

architecture rtl of overlay is

   constant C_WIDTH   : natural := 16;           -- Size of a digit in pixels
   constant C_HEIGHT  : natural := 32;
   constant C_FG      : std_logic_vector(7 downto 0) := X"FF";  -- White
   constant C_BG      : std_logic_vector(7 downto 0) := X"00";  -- Black

   -- The value shown in the current frame
   signal digits      : std_logic_vector(4*G_DIGITS-1 downto 0) := (others => '0');
   signal blank       : std_logic_vector(G_DIGITS-1 downto 0) := (others => '1');

   -- Stage 1: The position inside the overlay
   signal show_d1     : std_logic := '0';
   signal pos_d1      : natural range 0 to G_DIGITS-1 := 0;  -- Leftmost is 0
   signal col_d1      : std_logic_vector(3 downto 0) := (others => '0');
   signal row_d1      : std_logic_vector(4 downto 0) := (others => '0');

   -- Stage 2: The digit
   signal show_d2     : std_logic := '0';
   signal digit_d2    : std_logic_vector(3 downto 0) := (others => '0');
   signal col_d2      : std_logic_vector(3 downto 0) := (others => '0');
   signal row_d2      : std_logic_vector(4 downto 0) := (others => '0');

   -- Stage 3: The row of the digit from the font
   signal show_d3     : std_logic := '0';
   signal font_d3     : std_logic_vector(C_WIDTH-1 downto 0);
   signal col_d3      : std_logic_vector(3 downto 0) := (others => '0');

   -- Stage 4: The pixel of the digit
   signal show_d4     : std_logic := '0';
   signal fg_d4       : std_logic;

   -- Stage 5: Output
   signal vga_hs_d5   : std_logic;
   signal vga_vs_d5   : std_logic;
   signal vga_col_d5  : std_logic_vector(7 downto 0);

begin

   --------------------------------------------------
   -- Change the value shown before the first line of a frame
   --------------------------------------------------

   p_value : process (vga_clk_i)
   begin
      if rising_edge(vga_clk_i) then
         if vga_pix_x_i = 0 and vga_pix_y_i = 0 then
            digits <= fps_digits_i;
            blank  <= fps_blank_i;
         end if;
      end if;
   end process p_value;


   --------------------------------------------------
   -- Generate the overlay
   --------------------------------------------------

   p_overlay : process (vga_clk_i)
      variable x_v : std_logic_vector(10 downto 0);
      variable y_v : std_logic_vector(10 downto 0);
   begin
      if rising_edge(vga_clk_i) then
         -- Stage 1
         x_v := vga_pix_x_i - G_X;
         y_v := vga_pix_y_i - G_Y;
         show_d1 <= '0';
         if vga_pix_x_i >= G_X and vga_pix_x_i < G_X + C_WIDTH*G_DIGITS and
            vga_pix_y_i >= G_Y and vga_pix_y_i < G_Y + C_HEIGHT then
            show_d1 <= '1';
         end if;
         pos_d1 <= to_integer(x_v(10 downto 4)) mod G_DIGITS;
         col_d1 <= x_v(3 downto 0);
         row_d1 <= y_v(4 downto 0);

         -- Stage 2. The leftmost digit is the most significant one.
         show_d2  <= show_d1 and not blank(G_DIGITS-1-pos_d1);
         digit_d2 <= digits(4*(G_DIGITS-1-pos_d1)+3 downto 4*(G_DIGITS-1-pos_d1));
         col_d2   <= col_d1;
         row_d2   <= row_d1;

         -- Stage 3
         show_d3 <= show_d2;
         font_d3 <= C_FONT(to_integer(digit_d2 & row_d2));
         col_d3  <= col_d2;

         -- Stage 4
         show_d4 <= show_d3;
         fg_d4   <= font_d3(C_WIDTH-1-to_integer(col_d3));

         -- Stage 5
         vga_col_d5 <= vga_col_d4_i;
         if show_d4 = '1' then
            vga_col_d5 <= C_FG when fg_d4 = '1' else C_BG;
         end if;
         vga_hs_d5 <= vga_hs_d4_i;
         vga_vs_d5 <= vga_vs_d4_i;
      end if;
   end process p_overlay;


   --------------------------
   -- Connect output signals
   --------------------------

   vga_hs_o  <= vga_hs_d5;
   vga_vs_o  <= vga_vs_d5;
   vga_col_o <= vga_col_d5;

end architecture rtl;
