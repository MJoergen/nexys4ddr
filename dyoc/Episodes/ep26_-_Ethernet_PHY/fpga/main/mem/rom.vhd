library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

-- This module models a single-port asynchronous RAM.
-- Even though there are separate signals for data
-- input and data output, simultaneous read and write
-- will not be used in this design.
--
-- Data read is present half way through the same clock cycle.
-- This is done by using a synchronous Block RAM, and reading
-- on the *falling* edge of the clock cycle.

entity rom is
   generic (
      G_INIT_FILE : string;
      -- Number of bits in the address bus. The size of the memory will
      -- be 2**G_ADDR_BITS bytes.
      G_ADDR_BITS : integer
   );
   port (
      clk_i  : in  std_logic;

      -- Current address selected.
      addr_i : in  std_logic_vector(G_ADDR_BITS-1 downto 0);

      -- Data contents at the selected address.
      -- Valid in same clock cycle.
      data_o : out std_logic_vector(7 downto 0)
   );
end rom;

architecture structural of rom is

   -- This defines a type containing an array of bytes
   type mem_t is array (0 to 2**G_ADDR_BITS-1) of std_logic_vector(7 downto 0);

   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return mem_t is
      FILE RamFile : text;
      variable RamFileLine : line;
      variable RAM : mem_t := (others => (others => '0'));
   begin
      file_open(RamFile, RamFileName, read_mode);
      for i in mem_t'range loop
         readline (RamFile, RamFileLine);
         hread (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   -- Initialize memory contents
   signal mem : mem_t := InitRamFromFile(G_INIT_FILE);

   -- Data read from memory.
   signal data : std_logic_vector(7 downto 0);

begin

   -- Read process.
   -- Triggered on the *falling* clock edge in order to mimick an asynchronous
   -- memory.
   data_proc : process (clk_i)
   begin
      if falling_edge(clk_i) then
         data <= mem(to_integer(addr_i));
      end if;
   end process data_proc;

   -- Drive output signals
   data_o <= data;

end structural;

