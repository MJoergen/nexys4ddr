library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity vga_module is
   generic (
      G_CHAR_FILE : string
   );
   port (
      -- Clock
      clk_i : in  std_logic;                    -- 108 MHz
      rst_i : in  std_logic;

      -- VGA port
      hs_o  : out std_logic; 
      vs_o  : out std_logic;
      col_o : out std_logic_vector(11 downto 0)
   );
end vga_module;

architecture Structural of vga_module is

   -- Signals driven by the vga_ctrl block
   signal ctrl_hs     : std_logic; 
   signal ctrl_vs     : std_logic;
   signal ctrl_hcount : std_logic_vector(10 downto 0);
   signal ctrl_vcount : std_logic_vector(10 downto 0);
   signal ctrl_blank  : std_logic;

begin

   -- This generates the VGA timing signals
   inst_vga_ctrl : entity work.vga_ctrl
   port map (
      clk_i    => clk_i,
      rst_i    => rst_i,
      hs_o     => ctrl_hs,
      vs_o     => ctrl_vs,
      hcount_o => ctrl_hcount,
      vcount_o => ctrl_vcount,
      blank_o  => ctrl_blank       
   );

   -- This controls the display
   inst_vga_disp : entity work.vga_disp
   generic map (
                  G_CHAR_FILE => G_CHAR_FILE 
               )
   port map (
      clk_i    => clk_i,
      hsync_i  => ctrl_hs,
      vsync_i  => ctrl_vs,
      hcount_i => ctrl_hcount,
      vcount_i => ctrl_vcount,
      blank_i  => ctrl_blank,
      col_o    => col_o,
      hsync_o  => hs_o,
      vsync_o  => vs_o
   );

end Structural;

