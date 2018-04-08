library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This memory reads on falling clock edge.
-- Initial contents are read from a text file.

entity dmem_file is

   generic (
      G_ADDR_SIZE : integer;     -- Number of bits in address
      G_DATA_SIZE : integer;     -- Number of bits in data
      G_MEM_FILE  : string       -- Text file with initial memory contents
   );
   port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      addr_i    : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      wr_en_i   : in  std_logic;
      wr_data_i : in  std_logic_vector(G_DATA_SIZE-1 downto 0);
      rd_en_i   : in  std_logic;
      rd_data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );

end dmem_file;

architecture Structural of dmem_file is

   type t_rom is array (0 to 2**G_ADDR_SIZE-1) of std_logic_vector(G_DATA_SIZE-1 downto 0);

   -- This reads the ROM contents from a text file
   impure function InitRamFromFile(RamFileName : in string) return t_rom is
      FILE RamFile : text is in RamFileName;
      variable RamFileLine : line;
      variable RAM : t_rom := (others => (others => '0'));
   begin
      for i in t_rom'range loop
         readline (RamFile, RamFileLine);
         read (RamFileLine, RAM(i));
         if endfile(RamFile) then
            return RAM;
         end if;
      end loop;
      return RAM;
   end function;

   signal i_dmem_file : t_rom := InitRamFromFile(G_MEM_FILE);

   signal data : std_logic_vector(G_DATA_SIZE-1 downto 0) := (others => '0');

begin

   -- Write process, rising clock edge
   process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            i_dmem_file(conv_integer(addr_i)) <= wr_data_i;
         end if;
      end if;
   end process;

   -- Read process, falling clock edge
   process (clk_i)
   begin
      if falling_edge(clk_i) then
         if rd_en_i = '1' then
            data <= i_dmem_file(conv_integer(addr_i));
         end if;
      end if;
   end process;

   -- Drive output signals
   rd_data_o <= data;

end Structural;

