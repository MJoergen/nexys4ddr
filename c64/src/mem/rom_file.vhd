library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;
use std.textio.all;

-- This is a generic ROM instantiation from a text file.
entity rom_file is

   generic (
              G_RD_CLK_RIS : boolean;     -- True, if read port synchronized to rising clock edge
              G_ADDR_SIZE  : integer;     -- Number of bits in address
              G_DATA_SIZE  : integer;     -- Number of bits in data
              G_ROM_FILE   : string       -- Initial memory contents
   );
   port (
      clk_i  : in  std_logic;
      addr_i : in  std_logic_vector(G_ADDR_SIZE-1 downto 0);
      rden_i : in  std_logic;
      data_o : out std_logic_vector(G_DATA_SIZE-1 downto 0)
   );

end rom_file;

architecture Structural of rom_file is

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

   signal rom  : t_rom := InitRamFromFile(G_ROM_FILE);

   signal data : std_logic_vector(G_DATA_SIZE-1 downto 0);

begin

   -- This must be a clocked process in order to synthesize as a Block RAM.
   gen_rising : if G_RD_CLK_RIS = true generate
      process (clk_i)
      begin
         if rising_edge(clk_i) then
            if rden_i = '1' then
               data <= rom(conv_integer(addr_i));
            end if;
         end if;
      end process;
   end generate gen_rising;

   gen_falling : if G_RD_CLK_RIS = false generate
      process (clk_i)
      begin
         if falling_edge(clk_i) then
            if rden_i = '1' then
               data <= rom(conv_integer(addr_i));
            end if;
         end if;
      end process;
   end generate gen_falling;


   -- Drive output signals
   data_o <= data;

end Structural;

