library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module performs the address decoding and chip select.
-- It is therefore responsible for the overall systemn memory map.

-- The current sizes are:
-- ROM : 0x400
-- RAM : 0x400
-- VGA : 0x400

-- The current memory regions are:
-- 0xFC00 - 0xFFFF : ROM
-- 0x8000 - 0x83FF : VGA
-- 0x0000 - 0x03FF : RAM

entity cs is

   port (
      addr_i : in  std_logic_vector(15 downto 0);
      rom_o  : out std_logic;
      vga_o  : out std_logic;
      ram_o  : out std_logic
   );

end entity cs;

architecture Structural of cs is

begin

   rom_o <= '1' when addr_i(15 downto 10) = "111111" else '0';
   vga_o <= '1' when addr_i(15 downto 10) = "100000" else '0';
   ram_o <= '1' when addr_i(15 downto 10) = "000000" else '0';

end architecture Structural;

