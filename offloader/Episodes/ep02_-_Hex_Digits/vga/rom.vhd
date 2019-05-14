library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

entity rom is
   generic (
      G_ROM_FILE  : string;
      G_ADDR_SIZE : integer;
      G_DATA_SIZE : integer
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

