library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity beta is
   port (
      -- Clock
      clk_i       : in  std_logic;                    -- 100 MHz
      rstn_i      : in  std_logic;                    -- Active low.

      -- VGA port
      vga_hs_o    : out std_logic; 
      vga_vs_o    : out std_logic;
      vga_red_o   : out std_logic_vector(3 downto 0); 
      vga_green_o : out std_logic_vector(3 downto 0); 
      vga_blue_o  : out std_logic_vector(3 downto 0);

      -- Switches
      sw_i        : in  std_logic_vector(15 downto 0)
   );
end beta;

architecture Structural of beta is

   signal cpu_clk : std_logic;
   signal vga_clk : std_logic;

   signal val : std_logic_vector(31 downto 0);

begin

   -- This design uses two different clocks:
   -- vga_clk (108 MHz) drives the VGA output.
   -- cpu_clk (10 MHz) drives the CPU design.

   -- Generate VGA clock
   inst_clk_wiz_vga : entity work.clk_wiz_vga
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => vga_clk  -- 108 MHz
   );

   -- Generate CPU clock
   inst_clk_wiz_cpu : entity work.clk_wiz_cpu
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => cpu_clk  --  10 MHz
   );


   -- Instantiate the VGA module controlling the VGA display port.
   i_vga_module : entity work.vga_module
   port map
   (
      clk_i   => vga_clk,
      hs_o    => vga_hs_o,
      vs_o    => vga_vs_o,
      red_o   => vga_red_o,
      green_o => vga_green_o,
      blue_o  => vga_blue_o,
      val_i   => val
   );

   -- Instantiate the CPU module
   i_cpu_module : entity work.cpu_module
   port map
   (
      clk_i   => cpu_clk,
      rstn_i  => rstn_i,
      sw_i    => sw_i,
      val_o   => val          -- Debug output to be displayed on the screen
   );

end Structural;

