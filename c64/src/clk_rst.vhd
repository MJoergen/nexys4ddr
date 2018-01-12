library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module generates the clock and reset signals.

entity clk_rst is

   generic (
              G_SIMULATION : boolean
           );
   port (
           sys_clk_i  : in  std_logic;
           sys_rstn_i : in  std_logic;
           rst_cpu_o  : out std_logic;
           rst_vga_o  : out std_logic;
           clk_cpu_o  : out std_logic;
           clk_vga_o  : out std_logic
        );

end entity clk_rst;

architecture Structural of clk_rst is

   signal rst_cpu : std_logic;
   signal rst_vga : std_logic := '1';
   signal clk_cpu : std_logic;
   signal clk_vga : std_logic := '1';

begin

   ------------------------------
   -- Generate clocks. Speed up simulation by skipping the MMCME2_ADV
   ------------------------------

   gen_simulation: if G_SIMULATION = true  generate
      clk_vga <= sys_clk_i;
   end generate gen_simulation;

   gen_no_simulation: if G_SIMULATION = false  generate
      inst_clk_wiz_vga : entity work.clk_wiz_vga
      port map
      (
         clk_in1  => sys_clk_i,   -- 100 MHz
         clk_out1 => clk_vga  -- 25 MHz
      );
   end generate gen_no_simulation;

   clk_cpu <= sys_clk_i;


   ------------------------------
   -- Generate synchronous resets
   ------------------------------

   p_rst_cpu : process (clk_cpu)
   begin
      if rising_edge(clk_cpu) then
         rst_cpu <= not sys_rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_rst_cpu;

   p_rst_vga : process (clk_vga)
   begin
      if rising_edge(clk_vga) then
         rst_vga <= not sys_rstn_i;     -- Register, and invert polarity.
      end if;
   end process p_rst_vga;


   -----------------------
   -- Drive output signals
   -----------------------

   rst_cpu_o <= rst_cpu;
   rst_vga_o <= rst_vga;
   clk_cpu_o <= clk_cpu;
   clk_vga_o <= clk_vga;

end architecture Structural;

