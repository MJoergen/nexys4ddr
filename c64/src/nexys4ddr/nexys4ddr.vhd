library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level wrapper for the NEXYS4DDR board.
-- This is needed, because this design is meant to
-- work on both the BASYS2 and the NEXYS4DDR boards.
-- This file therefore contains all the stuff
-- peculiar to the NEXYS4DDR platform.

entity nexys4ddr is

   generic (
      G_SIMULATION : boolean := false
   );
   port (
      -- Clock
      clk100_i   : in  std_logic;   -- This pin is connected to an external 100 MHz crystal.

      -- Reset
      sys_rstn_i : in  std_logic;   -- Asserted low

      -- Input switches and push buttons
      sw_i       : in  std_logic_vector(15 downto 0);
      btn_i      : in  std_logic_vector(4 downto 0);

      -- Keyboard / mouse
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Output LEDs
      led_o      : out std_logic_vector(15 downto 0);

     -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0)
   );
end nexys4ddr;

architecture Structural of nexys4ddr is

   -- Clocks and Reset
   signal vga_clk   : std_logic;
   signal cpu_clk   : std_logic;
   signal cpu_rst   : std_logic;
 
   -- VGA color output
   signal vga_col   : std_logic_vector(7 downto 0);
 
   -- LED output
   signal led : std_logic_vector(7 downto 0);

   -- Convert colour from 8-bit format to 12-bit format
   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      return arg(7 downto 5) & "0" & arg(4 downto 2) & "0" & arg(1 downto 0) & "00";
   end function col8to12;

begin


   gen_vga_clock : if G_SIMULATION = false generate
      -- Generate VGA clock (25 MHz)
      inst_clk_wiz_vga : entity work.clk_wiz_vga
      port map
      (
         clk_in1  => clk100_i,
         clk_out1 => vga_clk
      );
    
    
      -- Generate CPU clock (??? MHz)
      inst_clk_wiz_cpu : entity work.clk_wiz_cpu
      port map
      (
         clk_in1  => clk100_i,
         clk_out1 => cpu_clk
      );
   end generate;

   gen_no_vga_clock : if G_SIMULATION = true generate
      vga_clk <= clk100_i;
      cpu_clk <= clk100_i;
   end generate;
 
 
   -- Generate synchronous CPU reset
   p_cpu_rst : process (cpu_clk)
   begin
      if rising_edge(cpu_clk) then
         cpu_rst <= not sys_rstn_i;     -- Synchronize and invert polarity.
      end if;
   end process p_cpu_rst;
 

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR  => true,              -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   => 11,                -- Number of bits in ROM address
      G_RAM_SIZE   => 11,                -- Number of bits in RAM address
      G_ROM_FILE   => "rom.txt",         -- Contains the machine code
      G_FONT_FILE  => "ProggyClean.txt"  -- Contains the character font
   )
   port map (
      vga_clk_i  => vga_clk,
      cpu_clk_i  => cpu_clk,
      cpu_rst_i  => cpu_rst,
      --
      mode_i     => sw_i(0),
      step_i     => btn_i(0),
      --
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      --
      led_o      => led,
      --
      vga_hs_o   => vga_hs_o,
      vga_vs_o   => vga_vs_o,
      vga_col_o  => vga_col
   );
 
 
   led_o(15 downto 8) <= (others => '0');
   led_o( 7 downto 0) <= led;

   vga_col_o <= col8to12(vga_col);
   
end Structural;

