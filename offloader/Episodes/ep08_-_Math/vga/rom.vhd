library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

-- This is a wrapper for a generic ROM.
-- The contents of the ROM is taken from a text file containing hexadecimal
-- values, one line for each address of the ROM.

-- Under normal circumstances, the Vivado tool will synthesize this into one or
-- more BRAM's with initial contents. No extra logic should be generated.

entity rom is
   generic (
      G_ROM_FILE  : string;      -- Text file used to initialize the contents of the ROM.
      G_ADDR_SIZE : integer;     -- Number of bits in the address bus.
      G_DATA_SIZE : integer      -- Number of bits in the data bus.
   );
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );
end rom;

architecture structural of rom is

   subtype data_t is std_logic_vector(G_DATA_SIZE-1 downto 0);

   type rom_t is array (0 to 2**G_ADDR_SIZE-1) of data_t;

   -- This reads the ROM contents from a text file
   impure function InitRomFromFile(RomFileName : in string) return rom_t is
      FILE RomFile : text;
      variable RomFileLine : line;
      variable ROM : rom_t := (others => (others => '0'));
   begin
      file_open(RomFile, RomFileName, read_mode);
      for i in rom_t'range loop
         readline (RomFile, RomFileLine);
         hread (RomFileLine, ROM(i));
         if endfile(RomFile) then
            return ROM;
         end if;
      end loop;
      return ROM;
   end function;

   constant rom : rom_t := InitRomFromFile(G_ROM_FILE);

   signal data : std_logic_vector(G_DATA_SIZE-1 downto 0);

begin

   -- Note, this is a clocked process. This is necessary to allow the use of a BRAM.
   -- If the clock is removed, then this block will be replaced with a large tree of combinatorial logic.
   p_data : process (clk_i)
   begin
      if rising_edge(clk_i) then
         data <= rom(to_integer(addr_i));
      end if;
   end process p_data;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   data_o <= data;

end architecture structural;

