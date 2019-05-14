library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

entity font is
   port (
      clk_i    : in  std_logic;

      -- Character to select the current bitmap.
      char_i   : in  std_logic_vector(7 downto 0);

      -- Bitmap of the selected character.
      bitmap_o : out std_logic_vector(63 downto 0)
   );
end font;

architecture structural of font is

   constant C_FONT_FILE : string := "font8x8.txt";

   -- A single character bitmap is defined by 8x8 = 64 bits.
   subtype bitmap_t is std_logic_vector(63 downto 0);

   -- The entire font is defined by an array bitmaps, one for each character.
   type bitmap_vector_t is array (0 to 255) of bitmap_t;


   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return bitmap_vector_t is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable RAM : bitmap_vector_t := (others => (others => '0'));
   begin
      for i in bitmap_vector_t'range loop
         readline (RamFile, RamFileLine);
         hread (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   constant bitmaps : bitmap_vector_t := InitRamFromFile(C_FONT_FILE);

   signal bitmap : std_logic_vector(63 downto 0);

begin

   p_bitmap : process (clk_i)
   begin
      if rising_edge(clk_i) then
         bitmap <= bitmaps(to_integer(char_i));
      end if;
   end process p_bitmap;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   bitmap_o <= bitmap;

end architecture structural;

