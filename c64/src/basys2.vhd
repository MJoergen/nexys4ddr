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

   signal cpu_rst : std_logic := '0';

begin

   -- Generate synchronous CPU reset
   p_cpu_rst : process (clk25_i)
   begin
      if rising_edge(clk25_i) then
         cpu_rst <= btn_i(3);     -- Synchronize input
      end if;
   end process p_cpu_rst;

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR  => false,             -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   => 11,                -- Number of bits in ROM address
      G_RAM_SIZE   => 11,                -- Number of bits in RAM address
      G_ROM_FILE   => "rom.txt",         -- Contains the machine code
      G_FONT_FILE  => "ProggyClean.txt"  -- Contains the character font
   )
   port map (
      vga_clk_i  => clk25_i,
      cpu_clk_i  => clk25_i,
      cpu_rst_i  => cpu_rst,
      --
      mode_i     => sw_i(0),
      step_i     => btn_i(0),
      --
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      --
      led_o      => led_o,
      --
      vga_hs_o   => vga_hs_o,
      vga_vs_o   => vga_vs_o,
      vga_col_o  => vga_col_o
  );

end Structural;

