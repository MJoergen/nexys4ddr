library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This is a generic ROM instantiation from a text file.
entity rom_file is

   generic (
      G_ADDR_SIZE : integer;     -- Number of bits in address
      G_DATA_SIZE : integer;     -- Number of bits in data
      G_CHAR_FILE : string
   );
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );

end rom_file;

architecture Structural of rom_file is

   type t_mem is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- This reads the ROM contents from a text file
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

   signal rom : t_mem := InitRamFromFile(G_CHAR_FILE);

begin

   -- This has to be registered in order to make it into a Block RAM.
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         data_o <= rom(conv_integer(addr_i));
      end if;
   end process;

end Structural;

