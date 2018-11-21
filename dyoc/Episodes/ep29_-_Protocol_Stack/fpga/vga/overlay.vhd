library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module implements an overlay containing debug information
-- It receives as input the current screen, and outputs
-- the modified screen.

entity overlay is
   generic (
      G_FONT_FILE : string
   );
   port (
      clk_i     : in  std_logic;

      pix_x_i   : in  std_logic_vector(9 downto 0);
      pix_y_i   : in  std_logic_vector(9 downto 0);
      digits_i  : in  std_logic_vector(239 downto 0);

      -- Current screen
      vga_hs_i  : in  std_logic;
      vga_vs_i  : in  std_logic;
      vga_col_i : in  std_logic_vector(7 downto 0);

      -- Modified screen with overlay
      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)
   );
end overlay;

architecture structural of overlay is

   -- Number of rows of text on screen
   constant NUM_ROWS : integer := digits_i'length / 16;

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
   constant DIGITS_CHAR_X : integer := 16;
   constant DIGITS_CHAR_Y : integer := 10;

   constant TEXT_CHAR_X   : integer := 10;
   constant TEXT_CHAR_Y   : integer := DIGITS_CHAR_Y;

   type txt_t is array (0 to 5*NUM_ROWS-1) of character;
   constant txt : txt_t := "TXDMA" & "ERROR" & " GOOD" & " KBD " & "XR YR" & "SP SR" & "W DA " & "ADDR " & "HI LO" &
                           "DI AR" & "  PC " & "IR CN" & " CTL1" & " CTL2" & " CTL3";

   -- A single character bitmap is defined by 8x8 = 64 bits.
   subtype bitmap_t is std_logic_vector(63 downto 0);


   -- Define colours
   constant COL_BLACK : std_logic_vector(7 downto 0) := B"000_000_00";
   constant COL_DARK  : std_logic_vector(7 downto 0) := B"001_001_01";
   constant COL_WHITE : std_logic_vector(7 downto 0) := B"111_111_11";
   constant COL_RED   : std_logic_vector(7 downto 0) := B"111_000_00";
   constant COL_GREEN : std_logic_vector(7 downto 0) := B"000_111_00";
   constant COL_BLUE  : std_logic_vector(7 downto 0) := B"000_000_11";


   signal digits_r : std_logic_vector(239 downto 0);

   -- Character coordinates
   signal char_col : integer range 0 to H_TOTAL/16-1;
   signal char_row : integer range 0 to V_TOTAL/16-1;

   -- Value of nibble at current position
   signal nibble_offset : integer range 0 to 4*NUM_ROWS-1;
   signal nibble_index  : integer range 0 to 4*NUM_ROWS-1;
   signal nibble        : std_logic_vector(3 downto 0);
   signal txt_offset    : integer range 0 to 5*NUM_ROWS-1;

   -- Bitmap of digit at current position
   signal char_nibble   : std_logic_vector(7 downto 0);
   signal char_txt      : std_logic_vector(7 downto 0);
   signal char          : std_logic_vector(7 downto 0);
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

   ---------------------------------------
   -- Register the input for better timing
   ---------------------------------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         digits_r <= digits_i;
      end if;
   end process;


   --------------------------------------------------
   -- Calculate character coordinates, within 40x30
   --------------------------------------------------

   char_col <= to_integer(pix_x_i(9 downto 4));
   char_row <= to_integer(pix_y_i(9 downto 4));


   --------------------------------------------------
   -- Calculate value of digit at current position ('0' or '1')
   --------------------------------------------------

   process (char_row, char_col, nibble_offset, nibble_index, digits_r)
   begin
      if char_row >= DIGITS_CHAR_Y and char_row < DIGITS_CHAR_Y+NUM_ROWS and
         char_col >= DIGITS_CHAR_X and char_col < DIGITS_CHAR_X+4 then
         nibble_offset <= (char_row - DIGITS_CHAR_Y)*4 + (char_col - DIGITS_CHAR_X);
         nibble_index  <= 4*NUM_ROWS-1 - nibble_offset;
         nibble        <= digits_r(4*nibble_index+3 downto 4*nibble_index);
      else
         nibble_offset <= 0;
         nibble_index  <= 0;
         nibble        <= "0000";
      end if;
   end process;

   process (char_row, char_col)
   begin
      if char_row >= TEXT_CHAR_Y   and char_row < TEXT_CHAR_Y+NUM_ROWS and
         char_col >= TEXT_CHAR_X   and char_col < TEXT_CHAR_X+5 then
         txt_offset <= (char_row - TEXT_CHAR_Y)*5 + (char_col - TEXT_CHAR_X);
      else
         txt_offset <= 0;
      end if;
   end process;


   --------------------------------------------------
   -- Calculate character to display at current position
   --------------------------------------------------

   char_nibble <= nibble + X"30" when nibble < 10 else
           nibble + X"41" - 10;

   char_txt    <= to_std_logic_vector(character'pos(txt(txt_offset)), 8);

   char <= char_nibble when char_row >= DIGITS_CHAR_Y and char_row < DIGITS_CHAR_Y+NUM_ROWS and
                            char_col >= DIGITS_CHAR_X and char_col < DIGITS_CHAR_X+4 else
           char_txt    when char_row >= TEXT_CHAR_Y   and char_row < TEXT_CHAR_Y+NUM_ROWS and
                            char_col >= TEXT_CHAR_X   and char_col < TEXT_CHAR_X+5 else
           X"20"; -- Fill the rest of the screen with spaces.


   --------------------------------------------------
   -- Calculate bitmap (64 bits) of digit at current position
   --------------------------------------------------

   i_font : entity work.font
   generic map (
      G_FONT_FILE => G_FONT_FILE
   )
   port map (
      char_i   => char,
      bitmap_o => bitmap
   );


   --------------------------------------------------
   -- Calculate pixel at current position ('0' or '1')
   --------------------------------------------------

   pix_col       <= to_integer(pix_x_i(3 downto 1));
   pix_row       <= 7 - to_integer(pix_y_i(3 downto 1));
   bitmap_index  <= pix_row*8 + pix_col;
   pix           <= bitmap(bitmap_index);


   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   p_vga_col : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if pix = '1' then
            vga.col <= COL_WHITE;
         else
            vga.col <= vga_col_i; -- Text background colour.
         end if;

         -- Make sure colour is black outside visible screen
         if pix_x_i >= H_PIXELS or pix_y_i >= V_PIXELS then
            vga.col <= COL_BLACK;
         end if;

      end if;
   end process p_vga_col;

   --------------------------------------------------
   -- Generate horizontal sync signal
   --------------------------------------------------

   p_vga_hs : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga.hs <= vga_hs_i;
      end if;
   end process p_vga_hs;

   --------------------------------------------------
   -- Generate vertical sync signal
   --------------------------------------------------

   p_vga_vs : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga.vs <= vga_vs_i;
      end if;
   end process p_vga_vs;



   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga.hs;
   vga_vs_o  <= vga.vs;
   vga_col_o <= vga.col;

end architecture structural;

