library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

entity opcodes is
   generic (
      G_OPCODES_FILE : string
   );
   port (
      -- Character to select the current opcodes character.
      addr_i : in  std_logic_vector(10 downto 0);

      -- Selected character.
      char_o : out std_logic_vector(7 downto 0)
   );
end opcodes;

architecture structural of opcodes is

   -- A single character is defined by 8 bits.
   subtype char_t is std_logic_vector(7 downto 0);

   -- The entire opcodes memory is defined by an array of characters.
   type char_vector_t is array (0 to 2047) of char_t;


   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return char_vector_t is
      FILE RamFile : text;
      variable RamFileLine : line;
      variable RAM : char_vector_t := (others => (others => '0'));
   begin
      file_open(RamFile, RamFileName, read_mode);
      for i in char_vector_t'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   constant chars : char_vector_t := InitRamFromFile(G_OPCODES_FILE);

   signal char : std_logic_vector(7 downto 0);

begin

   char <= chars(to_integer(addr_i));


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   char_o <= char;

end architecture structural;

