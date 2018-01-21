library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module performs the address decoding and chip select.
-- It is therefore responsible for the overall systemn memory map.

-- The RAM is placed at address 0x0000 and upwards.
-- The ROM is placed at address 0xFFFF and downwards.
-- The VGA is placed at address 0x8000 - 0x87FF

entity cs is

   generic (
      G_ROM_SIZE : integer;   -- Number of bits in ROM address
      G_RAM_SIZE : integer    -- Number of bits in RAM address
   );
   port (
      addr_i : in  std_logic_vector(15 downto 0);
      rom_o  : out std_logic;
      vga_o  : out std_logic;
      ram_o  : out std_logic
   );

end entity cs;

architecture Structural of cs is

   constant C_ONES  : std_logic_vector(15 downto G_ROM_SIZE) := (others => '1');
   constant C_ZEROS : std_logic_vector(15 downto G_ROM_SIZE) := (others => '0');

begin

   rom_o <= '1' when addr_i(15 downto G_ROM_SIZE) = C_ONES  else '0';
   ram_o <= '1' when addr_i(15 downto G_RAM_SIZE) = C_ZEROS else '0';
   vga_o <= '1' when addr_i(15 downto 11) = "10000" else '0';  -- Range 0x8000 to 0x87FF

end architecture Structural;

