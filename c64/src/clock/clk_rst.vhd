library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module generates the clock and reset signals.

entity clk_rst is

   generic (
              G_NEXYS4DDR  : boolean;             -- True, when using the Nexys4DDR board.
              G_SIMULATION : boolean
           );
   port (
           sys_clk_i  : in  std_logic;
           sys_rstn_i : in  std_logic;
           sys_mode_i : in  std_logic;    -- Select CPU clock between system and single step.
           sys_step_i : in  std_logic;
           cpu_rst_o  : out std_logic;
           vga_rst_o  : out std_logic;
           cpu_clk_o  : out std_logic;
           vga_clk_o  : out std_logic
        );

end entity clk_rst;

architecture Structural of clk_rst is

   signal cpu_rst      : std_logic := '1';
   signal vga_rst      : std_logic := '1';
   signal cpu_clk      : std_logic;
   signal vga_clk      : std_logic;
   signal cpu_clk_step : std_logic;

begin

   ------------------------------
   -- Instantiate Debounce
   ------------------------------

   inst_debounce : entity work.debounce
   port map (
      clk_i => cpu_clk,

      in_i  => sys_step_i,
      out_o => cpu_clk_step
   );



   ------------------------------
   -- Generate clocks. Speed up simulation by skipping the MMCME2_ADV
   ------------------------------


   gen_nexys4ddr : if G_NEXYS4DDR = true generate

      gen_simulation: if G_SIMULATION = true  generate
         vga_clk <= sys_clk_i;
         cpu_clk <= sys_clk_i;
      end generate gen_simulation;

      gen_no_simulation: if G_SIMULATION = false  generate
         inst_clk_wiz_vga : entity work.clk_wiz_vga
         port map
         (
            clk_in1  => sys_clk_i,   -- 100 MHz
            clk_out1 => vga_clk  -- 25 MHz
         );

         -- pragma synthesis_off
         inst_clk_wiz_cpu : entity work.clk_wiz_cpu
         port map
         (
            clk_in1  => sys_clk_i,   -- 100 MHz
            clk_out1 => cpu_clk  -- 20 MHz
         );
         -- pragma synthesis_on
         cpu_clk <= vga_clk;
      end generate gen_no_simulation;

   end generate gen_nexys4ddr;


   gen_no_nexys4ddr : if G_NEXYS4DDR = false generate
      cpu_clk <= sys_clk_i;
      vga_clk <= sys_clk_i;
   end generate gen_no_nexys4ddr;


   ------------------------------
   -- Generate synchronous resets
   ------------------------------

   p_cpu_rst : process (cpu_clk)
   begin
      if rising_edge(cpu_clk) then
         cpu_rst <= not sys_rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_cpu_rst;

   p_vga_rst : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_rst <= not sys_rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_vga_rst;


   -----------------------
   -- Drive output signals
   -----------------------

   cpu_rst_o <= cpu_rst;
   vga_rst_o <= vga_rst;
   vga_clk_o <= vga_clk;

   cpu_clk_o <= cpu_clk when sys_mode_i = '0' else cpu_clk_step;

end architecture Structural;

