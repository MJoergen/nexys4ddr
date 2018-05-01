library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity digits is
   port (
      clk_i     : in  std_logic;

      pix_x_i   : in  std_logic_vector(9 downto 0);
      pix_y_i   : in  std_logic_vector(9 downto 0);
      digits_i  : in  std_logic_vector(7 downto 0);

      vga_col_o : out std_logic_vector(7 downto 0)
   );
end digits;

architecture Structural of digits is

   -- Define screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Define colours
   constant COL_BLACK : std_logic_vector(7 downto 0) := B"000_000_00";
   constant COL_DARK  : std_logic_vector(7 downto 0) := B"001_001_01";
   constant COL_WHITE : std_logic_vector(7 downto 0) := B"111_111_11";
   constant COL_RED   : std_logic_vector(7 downto 0) := B"111_000_00";
   constant COL_GREEN : std_logic_vector(7 downto 0) := B"000_111_00";
   constant COL_BLUE  : std_logic_vector(7 downto 0) := B"000_000_11";

   -- Each character is 16x16 pixels, so the screen contains 40x30 characters.

   -- Define positioning of digits
   constant DIGITS_X : integer := 10;
   constant DIGITS_Y : integer := 15;

   subtype bitmap_t is std_logic_vector(63 downto 0);

   type bitmap_vector_t is array (natural range <>) of bitmap_t;

   -- Define bitmaps
   -- Taken from https://github.com/dhepper/font8x8/blob/master/font8x8_basic.h
   constant bitmaps : bitmap_vector_t(0 to 1) := (
      "01111100" &
      "11000110" &
      "11001110" &
      "11011110" &
      "11110110" &
      "11100110" &
      "01111100" &
      "00000000",

      "00110000" &
      "01110000" &
      "00110000" &
      "00110000" &
      "00110000" &
      "00110000" &
      "11111100" &
      "00000000");

   -- Character row and column
   signal char_col : std_logic_vector(5 downto 0);
   signal char_row : std_logic_vector(5 downto 0);

   signal pix_col : integer range 0 to 7;
   signal pix_row : integer range 0 to 7;

   -- Pixel colour
   signal vga_col : std_logic_vector(7 downto 0);

begin

   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   char_col <= pix_x_i(9 downto 4);
   char_row <= pix_y_i(9 downto 4);

   pix_col  <= 7 - conv_integer(pix_x_i(3 downto 1));
   pix_row  <= 7 - conv_integer(pix_y_i(3 downto 1));

   p_vga_col : process (clk_i)
      variable char_num_v : integer;
      variable digit_v    : std_logic;
      variable bitmap_v   : bitmap_t;
      variable pix_v      : std_logic;
   begin
      if rising_edge(clk_i) then

         -- Set the default background colour
         vga_col <= COL_DARK;

         if char_row = DIGITS_Y and
            char_col >= DIGITS_X and char_col < DIGITS_X+8 then

            -- Determine the bit value to show
            char_num_v := conv_integer(char_col)-DIGITS_X;
            digit_v := digits_i(7-char_num_v);

            -- Determine the bitmap of this bit value
            bitmap_v := bitmaps(conv_integer((0 => digit_v)));

            -- Determine the current pixel in the bitmap
            pix_v := bitmap_v(pix_row*8+pix_col);

            if pix_v = '1' then
               vga_col <= COL_WHITE;
            end if;
         end if;

         -- Make sure colour is black outside visible screen
         if pix_x_i >= H_PIXELS or pix_y_i >= V_PIXELS then
            vga_col <= COL_BLACK;
         end if;

      end if;
   end process p_vga_col;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_col_o <= vga_col;

end architecture Structural;

