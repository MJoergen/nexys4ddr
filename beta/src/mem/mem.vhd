library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use std.textio.all;

entity mem is
   generic (
      G_INIT_FILE : string := "lab6.txt"
   );
   port (
      clk_i    : in  std_logic;
      clken_i  : in  std_logic;
      ma_i     : in  std_logic_vector(31 downto 0);  -- Memory Address
      moe_i    : in  std_logic;                      -- Memory Output Enable
      mrd_o    : out std_logic_vector(31 downto 0);  -- Memory Read Data
      wr_i     : in  std_logic;                      -- Write
      mwd_i    : in  std_logic_vector(31 downto 0);  -- Memory Write Data
      ia_i     : in  std_logic_vector(31 downto 0);  -- Instruction Address
      id_o     : out std_logic_vector(31 downto 0)   -- Instruction Data
   );
end mem;

architecture Structural of mem is

   -- 1 KW = 4 KB of memory.
   type t_mem is array (0 to 1023) of std_logic_vector(31 downto 0);

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

   signal memory : t_mem := InitRamFromFile(G_INIT_FILE);

begin

   --assert ia_i(1 downto 0) = "00" report "Misaligned instruction" severity failure;

   -- 1 combinational read port.
   id_o <= memory(conv_integer(ia_i(11 downto 2)));

   -- 1 combinational read port.
   process (ma_i, moe_i)
   begin
      mrd_o <= (others => 'Z');
      if moe_i = '1' then
         mrd_o <= memory(conv_integer(ma_i(11 downto 2)));
      end if;
   end process;

   -- 1 clocked write port.
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if clken_i = '1' then
            if wr_i = '1' then
               memory(conv_integer(ma_i(11 downto 2))) <= mwd_i;
            end if;
         end if;
      end if;
   end process;

end Structural;

