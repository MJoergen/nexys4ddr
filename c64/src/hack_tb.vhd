----------------------------------------------------------------------------------
-- Company:  Granbo
-- Engineer: Michael Jørgensen
-- 
-- The file contains the top level test bench for the timer_demo
----------------------------------------------------------------------------------
library ieee;
use ieee.STD_LOGIC_1164.ALL;
use ieee.STD_LOGIC_UNSIGNED.ALL;

entity hack_tb is
end hack_tb;

architecture Structural of hack_tb is

   -- Clocks and resets
   signal cpu_clk  : std_logic;
   signal vga_clk  : std_logic;   -- 25 MHz for a 640x480 display.
   signal cpu_rst  : std_logic;
   -- The VGA port does not need a reset.

   signal mode     : std_logic;   -- Enable single-step mode.
   signal step     : std_logic;   -- Single step one CPU clock cycle.

   -- Keyboard / mouse
   signal ps2_clk  : std_logic;
   signal ps2_data : std_logic;

   -- Output LEDs
   signal led      : std_logic_vector( 7 downto 0);

   -- Output to VGA monitor
   signal vga_hs   : std_logic;
   signal vga_vs   : std_logic;
   signal vga_col  : std_logic_vector( 7 downto 0);

   signal test_running : boolean := true;

begin

   -- Generate VGA clock
   vga_clk_gen : process
   begin
     if not test_running then
       wait;
     end if;

     vga_clk <= '1', '0' after 20 ns; -- 25 MHz
     wait for 10 ns;
   end process vga_clk_gen;

   -- Generate clock
   cpu_clk_gen : process
   begin
     if not test_running then
       wait;
     end if;

     cpu_clk <= '1', '0' after 5 ns; -- 100 MHz
     wait for 10 ns;
   end process cpu_clk_gen;

   -- Generate reset
   cpu_rst <= '1', '0' after 100 ns;


   -- Instantiate DUT
   inst_hack : entity work.hack
   generic map (
      G_NEXYS4DDR  => true,              -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   => 10,                -- Number of bits in ROM address
      G_RAM_SIZE   => 10,                -- Number of bits in RAM address
      G_ROM_FILE   => "rom.txt",         -- Contains the machine code
      G_FONT_FILE  => "ProggyClean.txt"  -- Contains the character font
   )
   port map (
      cpu_clk_i  => cpu_clk,
      vga_clk_i  => vga_clk,
      cpu_rst_i  => cpu_rst,
      mode_i     => mode,
      step_i     => step,
      ps2_clk_i  => ps2_clk,
      ps2_data_i => ps2_data,
      led_o      => led,
      vga_hs_o   => vga_hs,
      vga_vs_o   => vga_vs,
      vga_col_o  => vga_col
    );

    test_running <= true, false after 1000 us;
   
end Structural;

