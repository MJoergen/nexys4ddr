library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module controls the memory map of the computer
-- by instantiating the different memory components
-- needed (RAM, ROM, etc), and by handling the necessary
-- address decoding.

entity mem is
   generic (
      G_ROM_INIT_FILE : string
   );
   port (
      clk_i  : in  std_logic;

      -- Current address selected.
      addr_i : in  std_logic_vector(15 downto 0);

      -- Data contents at the selected address.
      -- Valid in same clock cycle.
      data_o : out std_logic_vector(7 downto 0);

      -- New data to (optionally) be written to the selected address.
      data_i : in  std_logic_vector(7 downto 0);

      -- '1' indicates we wish to perform a write at the selected address.
      wren_i : in  std_logic
   );
end mem;

architecture structural of mem is

   signal rom_data : std_logic_vector(7 downto 0);
   signal rom_cs   : std_logic;
   signal ram_wren : std_logic;
   signal ram_data : std_logic_vector(7 downto 0);
   signal ram_cs   : std_logic;

begin

   -----------------------
   -- Instantiate the ROM
   -----------------------

   rom_inst : entity work.rom
   generic map (
      G_INIT_FILE => G_ROM_INIT_FILE,
      G_ADDR_BITS => 12  -- 4K bytes
   )
   port map (
      clk_i  => clk_i,
      addr_i => addr_i(11 downto 0),
      data_o => rom_data
   ); -- rom_inst
   

   -----------------------
   -- Instantiate the RAM
   -----------------------

   ram_inst : entity work.ram
   generic map (
      G_ADDR_BITS => 12  -- 4K bytes
   )
   port map (
      clk_i  => clk_i,
      addr_i => addr_i(11 downto 0),
      data_o => ram_data,
      data_i => data_i,
      wren_i => ram_wren
   ); -- ram_inst
   

   --------------------
   -- Address decoding
   --------------------

   -- Allow 4K bytes of ROM in the range 0xF000 - 0xFFFF.
   rom_cs <= '1' when addr_i(15 downto 12) = "1111" else
             '0';

   -- Allow 4K bytes of RAM in the range 0x0000 - 0x0FFF.
   ram_cs <= '1' when addr_i(15 downto 12) = "0000" else
             '0';

   ram_wren <= wren_i and ram_cs;

   data_o <= rom_data when rom_cs = '1' else
             ram_data when ram_cs = '1' else
             X"00";
  
end structural;

