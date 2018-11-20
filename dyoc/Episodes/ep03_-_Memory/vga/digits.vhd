library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module generates the VGA output signals based
-- on the current pixel counters. The module ensures
-- that the mutual relative timing between the
-- synchronization signals and colour signal adheres
-- to the VESA standard.

entity digits is
   port (
      clk_i     : in  std_logic;

      digits_i  : in  std_logic_vector(23 downto 0);

      pix_x_i   : in  std_logic_vector(9 downto 0);
      pix_y_i   : in  std_logic_vector(9 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)
   );
end digits;

architecture structural of digits is

   -- The following constants define a resolution of 640x480 @ 60 Hz.
   -- Requires a clock of 25.175 MHz.
   -- See page 17 in "VESA MONITOR TIMING STANDARD"
   -- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

   -- Each character is 16x16 pixels, so the screen contains 40x30 characters.

   -- Define positioning of first digit
   constant DIGITS_CHAR_X : integer := 10;
   constant DIGITS_CHAR_Y : integer := 15;

   -- A single character bitmap is defined by 8x8 = 64 bits.
   subtype bitmap_t is std_logic_vector(63 downto 0);

   -- The entire font is defined by an array bitmaps, one for each character.
   type bitmap_vector_t is array (natural range <>) of bitmap_t;

   -- Define bitmaps
   -- Taken from https://github.com/dhepper/font8x8/blob/master/font8x8_basic.h
   constant bitmaps : bitmap_vector_t := (
      -- Digit 0
      "01111100" &
      "11000110" &
      "11001110" &
      "11011110" &
      "11110110" &
      "11100110" &
      "01111100" &
      "00000000",

      -- Digit 1
      "00110000" &
      "01110000" &
      "00110000" &
      "00110000" &
      "00110000" &
      "00110000" &
      "11111100" &
      "00000000");

   -- Define colours
   constant COL_BLACK : std_logic_vector(7 downto 0) := B"000_000_00";
   constant COL_DARK  : std_logic_vector(7 downto 0) := B"001_001_01";
   constant COL_GREY  : std_logic_vector(7 downto 0) := B"010_010_01";
   constant COL_WHITE : std_logic_vector(7 downto 0) := B"111_111_11";
   constant COL_RED   : std_logic_vector(7 downto 0) := B"111_000_00";
   constant COL_GREEN : std_logic_vector(7 downto 0) := B"000_111_00";
   constant COL_BLUE  : std_logic_vector(7 downto 0) := B"000_000_11";

   -- Character coordinates
   signal char_col : integer range 0 to H_TOTAL/16-1;
   signal char_row : integer range 0 to V_TOTAL/16-1;

   -- Value of digit at current position
   signal digits_offset : integer range 0 to 23;
   signal digits_index  : integer range 0 to 23;
   signal digit         : std_logic;

   -- Bitmap of digit at current position
   signal bitmaps_index : integer range 0 to 1;
   signal bitmap        : bitmap_t;

   -- Pixel at current position
   signal pix_col       : integer range 0 to 7;
   signal pix_row       : integer range 0 to 7;
   signal bitmap_index  : integer range 0 to 63;
   signal pix           : std_logic;

   -- We group together all the VGA signals into a single record.
   -- This will be especially useful in later episodes.
   type t_vga is record
      -- Synchronization
      hs  : std_logic;
      vs  : std_logic;

      -- Pixel colour
      col : std_logic_vector(7 downto 0);
   end record t_vga;

   signal vga : t_vga;

begin

   --------------------------------------------------
   -- Calculate character coordinates, within 40x30
   --------------------------------------------------

   char_col <= to_integer(pix_x_i(9 downto 4));
   char_row <= to_integer(pix_y_i(9 downto 4));


   --------------------------------------------------
   -- Calculate value of digit at current position ('0' or '1')
   --------------------------------------------------

   digits_offset <= char_col - DIGITS_CHAR_X;
   digits_index  <= 23 - digits_offset;
   digit         <= digits_i(digits_index);


   --------------------------------------------------
   -- Calculate bitmap (64 bits) of digit at current position
   --------------------------------------------------

   bitmaps_index <= to_integer((0 => digit));
   bitmap        <= bitmaps(bitmaps_index);


   --------------------------------------------------
   -- Calculate pixel at current position ('0' or '1')
   --------------------------------------------------

   pix_col       <= 7 - to_integer(pix_x_i(3 downto 1));
   pix_row       <= 7 - to_integer(pix_y_i(3 downto 1));
   bitmap_index  <= pix_row*8 + pix_col;
   pix           <= bitmap(bitmap_index);


   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   vga_col_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Set the default screen background colour
         vga.col <= COL_GREY;

         -- Are we within the borders of the text?
         if char_row = DIGITS_CHAR_Y and
            char_col >= DIGITS_CHAR_X and char_col < DIGITS_CHAR_X+24 then

            if pix = '1' then
               vga.col <= COL_WHITE;   -- Text foreground colour.
            else
               vga.col <= COL_DARK;    -- Text background colour.
            end if;
         end if;

         -- Make sure colour is black outside visible screen
         if pix_x_i >= H_PIXELS or pix_y_i >= V_PIXELS then
            vga.col <= COL_BLACK;
         end if;

      end if;
   end process vga_col_proc;


   --------------------------------------------------
   -- Generate horizontal sync signal
   --------------------------------------------------

   vga_hs_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_i >= HS_START and pix_x_i < HS_START+HS_TIME then
            vga.hs <= '0';
         else
            vga.hs <= '1';
         end if;
      end if;
   end process vga_hs_proc;


   --------------------------------------------------
   -- Generate vertical sync signal
   --------------------------------------------------

   vga_vs_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_y_i >= VS_START and pix_y_i < VS_START+VS_TIME then
            vga.vs <= '0';
         else
            vga.vs <= '1';
         end if;
      end if;
   end process vga_vs_proc;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga.hs;
   vga_vs_o  <= vga.vs;
   vga_col_o <= vga.col;

end architecture structural;

