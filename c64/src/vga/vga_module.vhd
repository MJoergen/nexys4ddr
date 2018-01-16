library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga_module is
   generic (
      G_CHAR_FILE  : string;
      G_DO_RD_REG  : boolean;     -- Register on read port?
      G_RD_CLK_RIS : boolean      -- Rising clock on read port?
   );
   port (
      -- Clock
      vga_clk_i : in  std_logic;
      vga_rst_i : in  std_logic;
      cpu_clk_i : in  std_logic;
      cpu_rst_i : in  std_logic;

      -- VGA port @ vga_clk_i
      hs_o  : out std_logic; 
      vs_o  : out std_logic;
      col_o : out std_logic_vector(11 downto 0);

      -- Configuration @ cpu_clk_i
      cpu_addr_i : in  std_logic_vector(7 downto 0);
      cpu_wren_i : in  std_logic;
      cpu_data_i : in  std_logic_vector(7 downto 0);
      cpu_rden_i : in  std_logic;
      cpu_data_o : out std_logic_vector(7 downto 0);
      cpu_irq_o  : out std_logic
   );
end vga_module;

architecture Structural of vga_module is

   -- Signals driven by the vga_ctrl block
   signal ctrl_hs     : std_logic; 
   signal ctrl_vs     : std_logic;
   signal ctrl_hcount : std_logic_vector(10 downto 0);
   signal ctrl_vcount : std_logic_vector(10 downto 0);
   signal ctrl_blank  : std_logic;

   -- Signals driven by the vga_disp block
   signal disp_hs     : std_logic; 
   signal disp_vs     : std_logic;
   signal disp_hcount : std_logic_vector(10 downto 0);
   signal disp_vcount : std_logic_vector(10 downto 0);
   signal disp_col    : std_logic_vector(11 downto 0);

   -- Signals driven by the vga_sprite block
   signal sprite_hs     : std_logic; 
   signal sprite_vs     : std_logic;
   signal sprite_hcount : std_logic_vector(10 downto 0);
   signal sprite_vcount : std_logic_vector(10 downto 0);
   signal sprite_col    : std_logic_vector(11 downto 0);
   signal sprite_data   : std_logic_vector(7 downto 0);

begin

   -- This generates the VGA timing signals
   inst_vga_ctrl : entity work.vga_ctrl
   port map (
      clk_i    => vga_clk_i,
      rst_i    => vga_rst_i,

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
      clk_i    => vga_clk_i,

      hcount_i => ctrl_hcount,
      vcount_i => ctrl_vcount,
      hsync_i  => ctrl_hs,
      vsync_i  => ctrl_vs,
      blank_i  => ctrl_blank,

      hcount_o => disp_hcount,
      vcount_o => disp_vcount,
      hsync_o  => disp_hs,
      vsync_o  => disp_vs,
      col_o    => disp_col
   );

   inst_vga_sprite : entity work.vga_sprite
   generic map (
      G_DO_RD_REG  => G_DO_RD_REG,
      G_RD_CLK_RIS => G_RD_CLK_RIS
   )
   port map (
      vga_clk_i => vga_clk_i,
      vga_rst_i => vga_rst_i,
      cpu_clk_i => cpu_clk_i,
      cpu_rst_i => cpu_rst_i,

      hcount_i  => disp_hcount,
      vcount_i  => disp_vcount,
      hs_i      => disp_hs,
      vs_i      => disp_vs,
      col_i     => disp_col,

      hcount_o  => sprite_hcount,
      vcount_o  => sprite_vcount,
      hs_o      => sprite_hs,
      vs_o      => sprite_vs,
      col_o     => sprite_col,

      cpu_addr_i => cpu_addr_i,
      cpu_wren_i => cpu_wren_i,
      cpu_data_i => cpu_data_i,
      cpu_rden_i => cpu_rden_i,
      cpu_data_o => cpu_data_o,
      cpu_irq_o  => cpu_irq_o
   );

   hs_o  <= sprite_hs;
   vs_o  <= sprite_vs;
   col_o <= sprite_col;

end Structural;

