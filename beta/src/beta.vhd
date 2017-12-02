library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity beta is
   port (
      -- Clock
      clk_i       : in  std_logic;                    -- 100 MHz

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

   signal val : std_logic_vector(31 downto 0);

begin

   -- Everything in this module is drived by the system clock clk_i
   -- The only place where another clock (vga_clk) is used, is within
   -- the vga_module.

   -- Instantiate the VGA module controlling the VGA display port.
   i_vga_module : entity work.vga_module
   port map
   (
      clk_i       => clk_i,
      vga_hs_o    => vga_hs_o,
      vga_vs_o    => vga_vs_o,
      vga_red_o   => vga_red_o,
      vga_green_o => vga_green_o,
      vga_blue_o  => vga_blue_o,
      val_i       => val
   );

   -- Instantiate the CPU module
   i_cpu_module : entity work.cpu_module
   port map
   (
      clk_i   => clk_i,
      val_o   => val          -- Debug output to be displayed on the screen
   );

end Structural;

