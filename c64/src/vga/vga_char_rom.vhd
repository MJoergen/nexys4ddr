library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This contains 8x8 pixels for each of 256 characters.
-- This is eight bytes for each character, i.e. a total of 2 KB.
-- It reads the entire charset from a text file.
entity vga_char_rom is

   generic (
      G_CHAR_FILE : string
   );
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(7 downto 0);  -- Which of the 256 characters
      row_i  : in  std_logic_vector(2 downto 0);  -- Which of the 8 rows
      data_o : out std_logic_vector(7 downto 0)
   );

end vga_char_rom;

architecture Structural of vga_char_rom is

   type t_mem is array (0 to 2047) of std_logic_vector(7 downto 0);

   -- This reads the ROM contents from a text file
   -- Each line consists of 8 binary digits.
   impure function InitRamFromFile(RamFileName : in string) return t_mem is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable RAM : t_mem := (others => (others => '0'));
   begin
      for i in t_mem'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   signal char_rom : t_mem := InitRamFromFile(G_CHAR_FILE);

   signal data : std_logic_vector(7 downto 0);

begin

   -- This has to be registered in order to make it into a Block RAM.
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         data <= char_rom(conv_integer(addr_i & row_i));
      end if;
   end process;

   data_o <= data;

end Structural;

