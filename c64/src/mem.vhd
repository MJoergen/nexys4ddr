library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This module contains a memory with separate read and write data, but a single address port
-- It is not allowed to simultaneously read and write.

entity mem is

   generic (
      G_CHAR_FILE : string := ""
   );
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;

      addr_i : in  std_logic_vector(9 downto 0);
      wren_i : in  std_logic;
      data_i : in  std_logic_vector(7 downto 0);
      rden_i : in  std_logic;
      data_o : out std_logic_vector(7 downto 0)
   );

end entity mem;

architecture Structural of mem is

   type t_mem is array (0 to 1023) of std_logic_vector(7 downto 0);

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

   signal mem : t_mem := InitRamFromFile(G_CHAR_FILE);

begin

   p_assert : process (clk_i)
   begin
      if falling_edge(clk_i) then
         if wren_i = '1' and rden_i = '1' then
            assert false report "Simultaneous read and write" severity failure;
         end if;
      end if;
   end process p_assert;


   p_write : process (clk_i)
   begin
      if falling_edge(clk_i) then
         if wren_i = '1' then
            mem(conv_integer(addr_i)) <= data_i;
         end if;
      end if;
   end process p_write;


   p_read : process (clk_i)
   begin
      if falling_edge(clk_i) then
         if rden_i = '1' then
            data_o <= mem(conv_integer(addr_i));
         end if;
      end if;
   end process p_read;

end architecture Structural;

