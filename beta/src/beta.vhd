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

   -- VGA signals
   signal vga_clk   : std_logic;                        -- 108 MHz
   signal hcount    : std_logic_vector(10 downto 0);
   signal vcount    : std_logic_vector(10 downto 0);
   signal blank     : std_logic;
   signal vga_color : std_logic_vector(11 downto 0);

begin

   -- Generate VGA clock
   inst_clk_wiz_0 : entity work.clk_wiz_0
   port map
   (
      clk_in1  => clk_i,
      clk_out1 => vga_clk
   );

   -- This generates the VGA timing signals
   inst_vga_ctrl : entity work.vga_ctrl
   port map (
      vga_clk_i => vga_clk,
      HS_o      => vga_hs_o,
      VS_o      => vga_vs_o,
      hcount_o  => hcount,
      vcount_o  => vcount,
      blank_o   => blank       
   );

   inst_vga_disp : entity work.vga_disp
   port map (
      vga_clk_i => vga_clk,
      hcount_i  => hcount,
      vcount_i  => vcount,
      blank_i   => blank,
      val_i     => sw_i(0),
      vga_o     => vga_color
   );

   vga_red_o   <= vga_color(11 downto 8);
   vga_green_o <= vga_color( 7 downto 4);
   vga_blue_o  <= vga_color( 3 downto 0);

end Structural;

