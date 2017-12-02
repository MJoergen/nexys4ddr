library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga_module is
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
      val_i       : in  std_logic_vector(31 downto 0)
   );
end vga_module;

architecture Structural of vga_module is

   -- VGA signals
   signal vga_clk   : std_logic := '0';                        -- 108 MHz

   signal vga_hs    : std_logic; 
   signal vga_vs    : std_logic;
   signal hcount    : std_logic_vector(10 downto 0);
   signal vcount    : std_logic_vector(10 downto 0);
   signal blank     : std_logic;

   signal vga_red   : std_logic_vector(3 downto 0); 
   signal vga_green : std_logic_vector(3 downto 0); 
   signal vga_blue  : std_logic_vector(3 downto 0);

begin

   -- Everything in this module is controlled by the clock
   -- vga_clk (108 MHz) derived from the system clock clk_i (100 MHz).

   -- Generate VGA clock
   inst_clk_wiz_0 : entity work.clk_wiz_0
   port map
   (
      clk_in1  => clk_i,   -- 100 MHz
      clk_out1 => vga_clk  -- 108 MHz
   );


   -- This generates the VGA timing signals
   inst_vga_ctrl : entity work.vga_ctrl
   port map (
      vga_clk_i => vga_clk,
      HS_o      => vga_hs,
      VS_o      => vga_vs,
      hcount_o  => hcount,
      vcount_o  => vcount,
      blank_o   => blank       
   );

   -- This controls the display
   inst_vga_disp : entity work.vga_disp
   port map (
      vga_clk_i   => vga_clk,
      vga_hsync_i => vga_hs,
      vga_vsync_i => vga_vs,
      hcount_i    => hcount,
      vcount_i    => vcount,
      blank_i     => blank,
      val_i       => val_i,
      vga_red_o   => vga_red_o,
      vga_green_o => vga_green_o,
      vga_blue_o  => vga_blue_o,
      vga_hsync_o => vga_hs_o,
      vga_vsync_o => vga_vs_o
   );

end Structural;

