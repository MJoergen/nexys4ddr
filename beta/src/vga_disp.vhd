----------------------------------------------------------------------------------
-- Description:  This generates the horizontal and vertical synchronization signals
--               for a VGA display with 1280 * 1024 @ 60 Hz refresh rate.
--               User must supply a 108 MHz clock on the input.
--               This is because 1688 * 1066 * 60 Hz = 107,96 MHz.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity vga_disp is
   port (
      vga_clk_i : in  std_logic;   -- This must be 108 MHz

      hcount_i  : in  std_logic_vector(10 downto 0);
      vcount_i  : in  std_logic_vector(10 downto 0);
      blank_i   : in  std_logic;
      
      val_i     : in  std_logic;
      vga_o     : out std_logic_vector(11 downto 0)
   );
end vga_disp;

architecture Behavioral of vga_disp is

   -- Define some common colours
   constant vga_white   : std_logic_vector(11 downto 0) := "1111" & "1111" & "1111";
   constant vga_light   : std_logic_vector(11 downto 0) := "1100" & "1100" & "1100";
   constant vga_gray    : std_logic_vector(11 downto 0) := "1000" & "1000" & "1000";
   constant vga_dark    : std_logic_vector(11 downto 0) := "0100" & "0100" & "0100";
   constant vga_black   : std_logic_vector(11 downto 0) := "0000" & "0000" & "0000";
   constant vga_red     : std_logic_vector(11 downto 0) := "1111" & "0000" & "0000";
   constant vga_green   : std_logic_vector(11 downto 0) := "0000" & "1111" & "0000";
   constant vga_blue    : std_logic_vector(11 downto 0) := "0000" & "0000" & "1111";
   constant vga_cyan    : std_logic_vector(11 downto 0) := "0000" & "1111" & "1111";
   constant vga_magenta : std_logic_vector(11 downto 0) := "1111" & "0000" & "1111";
   constant vga_yellow  : std_logic_vector(11 downto 0) := "1111" & "1111" & "0000";

   constant OFFSET_X    : integer := 600;
   constant OFFSET_Y    : integer := 400;
   constant CHAR_WIDTH  : integer := 11;
   constant CHAR_HEIGHT : integer := 16;

   subtype vga_bitmap_t is std_logic_vector(0 to CHAR_WIDTH * CHAR_HEIGHT - 1);

   constant vga_bitmap_char_0 : vga_bitmap_t := (
      "00000000000" &
      "00000000000" &
      "00001110000" &
      "00010001000" &
      "00100000100" &
      "00100000100" &
      "00100000100" &
      "00100000100" &
      "00100000100" &
      "00100000100" &
      "00100000100" &
      "00100000100" &
      "00010001000" &
      "00001110000" &
      "00000000000" &
      "00000000000");

   constant vga_bitmap_char_1 : vga_bitmap_t := (
      "00000000000" &
      "00000000000" &
      "00001100000" &
      "00110100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00000100000" &
      "00111111100" &
      "00000000000" &
      "00000000000");

   signal val_d  : std_logic;
   signal val_d2 : std_logic;

begin

   -- Clock synchronizer
   p_sync : process (vga_clk_i) is
   begin
      if rising_edge(vga_clk_i) then
         val_d  <= val_i;
         val_d2 <= val_d;
      end if;
   end process p_sync;

   gen_vga : process (hcount_i, vcount_i, blank_i) is
      variable hcount : integer;
      variable vcount : integer;
      variable xdiff  : integer range 0 to CHAR_WIDTH-1;
      variable ydiff  : integer range 0 to CHAR_HEIGHT-1;
      variable bitmap : vga_bitmap_t;
   begin
      hcount := conv_integer(hcount_i);
      vcount := conv_integer(vcount_i);

      vga_o <= vga_black; -- Outside visible area, the color must be black.

      if blank_i = '0' then
         vga_o <= vga_gray; -- Default background color on screen.

         if (hcount >= OFFSET_X) and (hcount < OFFSET_X + 2*CHAR_WIDTH)
         and (vcount >= OFFSET_Y) and (vcount < OFFSET_Y + 2*CHAR_HEIGHT) then
            xdiff := (hcount - OFFSET_X) / 2;
            ydiff := (vcount - OFFSET_Y) / 2;
            
            if val_d2 = '1' then
               bitmap := vga_bitmap_char_1;
            else
               bitmap := vga_bitmap_char_0;
            end if;

            if bitmap(ydiff*CHAR_WIDTH + xdiff) = '1' then
               vga_o <= vga_dark;
            end if;
         end if;

      end if;

   end process gen_vga;

end Behavioral;

