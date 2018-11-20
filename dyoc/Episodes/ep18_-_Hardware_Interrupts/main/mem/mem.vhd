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
      wren_i : in  std_logic;

      stat_o : out std_logic_vector(7 downto 0)
   );
end mem;

architecture structural of mem is

   signal rom_wren : std_logic;
   signal rom_data : std_logic_vector(7 downto 0);
   signal ram_wren : std_logic;
   signal ram_data : std_logic_vector(7 downto 0);
   signal cic_wren : std_logic;
   signal cic_data : std_logic_vector(7 downto 0);

begin

   ----------------------
   -- Instantiate the ROM
   ----------------------

   rom_inst : entity work.rom
   generic map (
      G_INIT_FILE => G_ROM_INIT_FILE,
      G_ADDR_BITS => 14  -- 16K bytes
   )
   port map (
      clk_i  => clk_i,
      addr_i => addr_i(13 downto 0),
      data_o => rom_data,
      data_i => data_i,
      wren_i => rom_wren
   ); -- rom_inst
   

   ----------------------
   -- Instantiate the RAM
   ----------------------

   ram_inst : entity work.ram
   generic map (
      G_ADDR_BITS => 11  -- 2K bytes
   )
   port map (
      clk_i  => clk_i,
      addr_i => addr_i(10 downto 0),
      data_o => ram_data,
      data_i => data_i,
      wren_i => ram_wren
   ); -- ram_inst
   

   ----------------------
   -- Instantiate the CIC
   ----------------------

   cic_inst : entity work.cic
   port map (
      clk_i  => clk_i,
      data_o => cic_data,
      data_i => data_i,
      wren_i => cic_wren,
      stat_o => stat_o
   ); -- cic_inst
   

   ----------------------
   -- Address decoding
   ----------------------

   rom_wren <= wren_i when addr_i(15 downto 14) = "11"    else
               '0';
   ram_wren <= wren_i when addr_i(15 downto 11) = "00000" else
               '0';
   cic_wren <= wren_i when addr_i = X"BFFF"               else
               '0';

   data_o <= rom_data when addr_i(15 downto 14) = "11"    else
             ram_data when addr_i(15 downto 11) = "00000" else
             cic_data when addr_i = X"BFFF"               else
             X"00";
  
end structural;

