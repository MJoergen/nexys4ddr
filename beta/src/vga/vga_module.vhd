library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga_module is
   port (
      -- Clock
      clk_i   : in  std_logic;                    -- 108 MHz

      -- VGA port
      hs_o    : out std_logic; 
      vs_o    : out std_logic;
      red_o   : out std_logic_vector(3 downto 0); 
      green_o : out std_logic_vector(3 downto 0); 
      blue_o  : out std_logic_vector(3 downto 0);

      -- Data to display
      regs_i    : in  std_logic_vector(1023 downto 0);
      ia_i      : in  std_logic_vector(  31 downto 0);
      count_i   : in  std_logic_vector(   7 downto 0);
      imem_id_i : in  std_logic_vector(  31 downto 0);
      irq_i     : in  std_logic
   );
end vga_module;

architecture Structural of vga_module is

   -- VGA signals
   signal vga_hs    : std_logic; 
   signal vga_vs    : std_logic;
   signal hcount    : std_logic_vector(10 downto 0);
   signal vcount    : std_logic_vector(10 downto 0);
   signal blank     : std_logic;

begin

   -- Everything in this module is controlled by the clock
   -- vga_clk (108 MHz) derived from the system clock clk_i (100 MHz).


   -- This generates the VGA timing signals
   inst_vga_ctrl : entity work.vga_ctrl
   port map (
      vga_clk_i => clk_i,
      HS_o      => vga_hs,
      VS_o      => vga_vs,
      hcount_o  => hcount,
      vcount_o  => vcount,
      blank_o   => blank       
   );

   -- This controls the display
   inst_vga_disp : entity work.vga_disp
   port map (
      vga_clk_i   => clk_i,
      vga_hsync_i => vga_hs,
      vga_vsync_i => vga_vs,
      hcount_i    => hcount,
      vcount_i    => vcount,
      blank_i     => blank,
      regs_i      => regs_i,
      ia_i        => ia_i,
      count_i     => count_i,
      imem_id_i   => imem_id_i,
      irq_i       => irq_i,
      vga_red_o   => red_o,
      vga_green_o => green_o,
      vga_blue_o  => blue_o,
      vga_hsync_o => hs_o,
      vga_vsync_o => vs_o
   );

end Structural;

