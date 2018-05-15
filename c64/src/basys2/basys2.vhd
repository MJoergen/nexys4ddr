library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level wrapper for the BASYS2 board.
-- This is needed, because this design is meant to
-- work on both the BASYS2 and the NEXYS4DDR boards.
-- This file therefore contains all the stuff
-- peculiar to the BASYS2 platform.

entity basys2 is

   port (
      -- Clock
      clk25_i    : in  std_logic;  -- We assume here this pin is connected to an external 25 MHz crystal.

      -- Input switches and push buttons
      sw_i       : in  std_logic_vector(7 downto 0);
      btn_i      : in  std_logic_vector(3 downto 0);

      -- Keyboard / mouse
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Output LEDs
      led_o      : out std_logic_vector(7 downto 0);

     -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(7 downto 0)
  );

end basys2;

architecture Structural of basys2 is

   signal rst : std_logic := '1';

begin

   -- Generate synchronous CPU reset
   p_rst : process (clk25_i)
   begin
      if rising_edge(clk25_i) then
         rst <= btn_i(3);     -- Synchronize input
      end if;
   end process p_rst;

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR => false,              -- False, when using the BASYS2 board.
      G_ROM_SIZE  => 11,                 -- Number of bits in ROM address
      G_RAM_SIZE  => 11,                 -- Number of bits in RAM address
      G_DISP_SIZE => 10,                 -- Number of bits in DISP address
      G_COL_SIZE  => 10,                 -- Number of bits in COL address
      G_FONT_SIZE => 12,                 -- Number of bits in FONT address
      G_MOB_SIZE  => 7,                  -- Number of bits in MOB address
      G_CONF_SIZE => 5,                  -- Number of bits in CONF address
      G_RAM_MASK  => X"0000",            -- Last address 0x07FF
      G_DISP_MASK => X"8000",            -- Last address 0x83FF
      G_COL_MASK  => X"8800",            -- Last address 0x8BFF
      G_MOB_MASK  => X"8400",            -- Last address 0x847F
      G_CONF_MASK => X"8600",            -- Last address 0x861F
      G_FONT_MASK => X"9000",            -- Last address 0x9FFF
      G_ROM_MASK  => X"F800",            -- Last address 0xFFFF
      G_ROM_FILE  => "rom.txt",          -- Contains the machine code
      G_FONT_FILE => "ProggyClean.txt"   -- Contains the character font
   )
   port map (
      cpu_clk_i     => clk25_i,
      cpu_rst_i     => rst,
      cpu_step_i    => '1',
      cpu_led_o     => led_o,
      --
      vga_clk_i     => clk25_i,
      vga_rst_i     => rst,
      vga_hs_o      => vga_hs_o,
      vga_vs_o      => vga_vs_o,
      vga_col_o     => vga_col_o,
      vga_overlay_i => sw_i(3 downto 1),
      vga_debug_i   => (others => '0'),
      --
      ps2_clk_i     => ps2_clk_i,
      ps2_data_i    => ps2_data_i
  );

end Structural;

