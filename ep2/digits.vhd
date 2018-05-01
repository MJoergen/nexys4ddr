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

   -- Define colours
   constant COL_BLACK : std_logic_vector(7 downto 0) := B"000_000_00";
   constant COL_WHITE : std_logic_vector(7 downto 0) := B"111_111_11";
   constant COL_RED   : std_logic_vector(7 downto 0) := B"111_000_00";
   constant COL_GREEN : std_logic_vector(7 downto 0) := B"000_111_00";
   constant COL_BLUE  : std_logic_vector(7 downto 0) := B"000_000_11";

   -- Define bitmaps
   constant zero : std_logic_vector(63 downto 0) :=
      "01110000" &
      "10001000" &
      "10001000" &
      "10001000" &
      "10001000" &
      "10001000" &
      "01110000" &
      "00000000";

   constant one : std_logic_vector(63 downto 0) :=
      "00010000" &
      "00110000" &
      "01010000" &
      "00010000" &
      "00010000" &
      "00010000" &
      "01111000" &
      "00000000";

   -- Pixel colour
   signal vga_col : std_logic_vector(7 downto 0);

   signal row : integer range 0 to 7;
   signal col : integer range 0 to 7;
   signal char_x : std_logic_vector(5 downto 0);
   signal char_y : std_logic_vector(5 downto 0);

begin


   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   char_x <= pix_x_i(9 downto 4);
   char_y <= pix_y_i(9 downto 4);
   col    <= 7 - conv_integer(pix_x_i(3 downto 1));
   row    <= 7 - conv_integer(pix_y_i(3 downto 1));

   p_col : process (clk_i)
      variable digit_v  : std_logic;
      variable offset_v : integer;
      variable pix_v    : std_logic;
   begin
      if rising_edge(clk_i) then
         vga_col <= COL_BLACK;

         if char_y = 15 and char_x >= 20 and char_x < 28 then
            offset_v := conv_integer(char_x)-20;
            digit_v := digits_i(7-offset_v);

            if digit_v = '1' then
               pix_v := one(row*8+col);
            else
               pix_v := zero(row*8+col);
            end if;

            if pix_v = '1' then
               vga_col <= COL_WHITE;
            end if;
         end if;
      end if;
   end process p_col;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_col_o <= vga_col;

end architecture Structural;

