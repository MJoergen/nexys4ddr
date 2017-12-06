library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use std.textio.all;

entity imem is
   generic (
      G_INIT_FILE : string := "imem.txt"
   );
   port (
      ia_i : in  std_logic_vector(31 downto 0);  -- Instruction Address
      id_o : out std_logic_vector(31 downto 0)   -- Instruction Data
   );
end imem;

architecture Structural of imem is

   -- 1 KW = 4 KB of instruction memory.
   type t_imem is array (0 to 1023) of std_logic_vector(31 downto 0);

   impure function InitRamFromFile(RamFileName : in string) return t_imem is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable RAM : t_imem := (others => (others => '0'));
   begin
      for i in t_imem'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   signal memory : t_imem := InitRamFromFile(G_INIT_FILE);

begin

   --assert ia_i(1 downto 0) = "00" report "Misaligned instruction" severity failure;

   -- 1 combinational read port.
   id_o <= memory(conv_integer(ia_i(11 downto 2)));

end Structural;

