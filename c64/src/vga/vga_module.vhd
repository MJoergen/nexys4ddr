------------------------------------------------------------
-- This is the top level of the VGA driver
-- It consists of three main blocks:
-- * Sync    : Generates the Hsync and Vsync signals
-- * Chars   : Generates a 40x18 character display
-- * Sprites : Generates 4 sprites
-- There are a number of additional blocks, dealing mainly
-- with the Clock Crossing between VGA and CPU clock domains.
--
-- A note on naming convention: Since this module uses two asynchronuous clock
-- domains, all signal names are prefixed with the corresponding clock domain,
-- i.e. cpu_ or vga_.
--
-- Memory Map:
-- 0x8000 - 0x83FF : Chars Memory
-- 0x8400 - 0x85FF : Bitmap Memory
-- 0x8600 - 0x87FF : Config and Status
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vga_module is
   generic (
      G_NEXYS4DDR : boolean;             -- True, when using the Nexys4DDR board.
      G_FONT_FILE : string
   );
   port (
      -- VGA port @ vga_clk_i
      vga_clk_i  : in  std_logic;
      vga_rst_i  : in  std_logic;
      --
      vga_hs_o   : out std_logic; 
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0);

      -- CPU port @ cpu_clk_i
      cpu_clk_i    : in  std_logic;
      cpu_rst_i    : in  std_logic;
      --
      cpu_addr_i   : in  std_logic_vector(10 downto 0);
      cpu_rden_i   : in  std_logic;
      cpu_data_o   : out std_logic_vector(7 downto 0);
      --
      cpu_wren_i   : in  std_logic;
      cpu_data_i   : in  std_logic_vector(7 downto 0);
      --
      cpu_irq_o      : out std_logic;
      cpu_status_i   : in  std_logic_vector(127 downto 0);
      cpu_key_rden_o : out std_logic;
      cpu_key_val_i  : in  std_logic_vector(7 downto 0);
      cpu_keyboard_debug_i : in  std_logic_vector(69 downto 0);

      debug_o      : out std_logic_vector(7 downto 0)
   );
end vga_module;

architecture Structural of vga_module is
   
   -- These must be the same as defined in src/vga/sync.vhd
   constant FRAME_WIDTH  : natural := 640;
   constant FRAME_HEIGHT : natural := 480;

   -- Signals driven by the Sync block
   signal vga_sync_hs     : std_logic; 
   signal vga_sync_vs     : std_logic;
   signal vga_sync_hcount : std_logic_vector(10 downto 0);
   signal vga_sync_vcount : std_logic_vector(10 downto 0);
   signal vga_sync_blank  : std_logic;

   -- Signals driven by the Character Display block
   signal vga_char_hs     : std_logic; 
   signal vga_char_vs     : std_logic;
   signal vga_char_hcount : std_logic_vector(10 downto 0);
   signal vga_char_vcount : std_logic_vector(10 downto 0);
   signal vga_char_col    : std_logic_vector(11 downto 0);
   --
   signal vga_char_font_addr : std_logic_vector(11 downto 0);
   signal vga_char_font_data : std_logic_vector( 7 downto 0);
   --
   signal vga_char_disp_addr : std_logic_vector( 9 downto 0);
   signal vga_char_disp_data : std_logic_vector( 7 downto 0);

   -- Signals driven by the Sprite Display block
   signal vga_sprite_hs     : std_logic; 
   signal vga_sprite_vs     : std_logic;
   signal vga_sprite_hcount : std_logic_vector(10 downto 0);
   signal vga_sprite_vcount : std_logic_vector(10 downto 0);
   signal vga_sprite_col    : std_logic_vector(11 downto 0);

   -- Signals driven by the Sprite Bitmap block
   signal vga_bitmap_addr   : std_logic_vector( 5 downto 0);
   signal vga_bitmap_data   : std_logic_vector(15 downto 0);

   -- Signals related to the CPU port
   signal cpu_cs_chars     : std_logic;
   signal cpu_wren_chars   : std_logic;
   signal cpu_rden_chars   : std_logic;
   signal cpu_rddata_chars : std_logic_vector(7 downto 0);

   signal cpu_cs_bitmaps     : std_logic;
   signal cpu_wren_bitmaps   : std_logic;
   signal cpu_rden_bitmaps   : std_logic;
   signal cpu_rddata_bitmaps : std_logic_vector(7 downto 0);

   signal cpu_cs_conf_stat     : std_logic;
   signal cpu_wren_conf_stat   : std_logic;
   signal cpu_rden_conf_stat   : std_logic;
   signal cpu_rddata_conf_stat : std_logic_vector(7 downto 0);

   -- Clock domain crossing
   signal vga_config : std_logic_vector(128*8-1 downto 0);
   signal vga_sync   : std_logic;
   signal cpu_config : std_logic_vector(128*8-1 downto 0);
   signal cpu_sync   : std_logic;
   signal vga_status : std_logic_vector(127 downto 0);
   signal vga_keyboard_debug : std_logic_vector(69 downto 0);

begin

   --=====================================================
   -- CPU Clock Domain
   --=====================================================

   --------------------------------------
   -- Address decoding
   -- 0x0000 - 0x03FF : Chars Memory
   -- 0x0400 - 0x05FF : Bitmap Memory
   -- 0x0600 - 0x07FF : Config and Status
   --------------------------------------

   cpu_cs_chars     <= '1' when cpu_addr_i(10)          = '0'  else '0';
   cpu_cs_bitmaps   <= '1' when cpu_addr_i(10 downto 9) = "10" else '0';
   cpu_cs_conf_stat <= '1' when cpu_addr_i(10 downto 9) = "11" else '0';

   cpu_wren_chars     <= cpu_wren_i and cpu_cs_chars;
   cpu_rden_chars     <= cpu_rden_i and cpu_cs_chars;
   cpu_wren_bitmaps   <= cpu_wren_i and cpu_cs_bitmaps;
   cpu_rden_bitmaps   <= cpu_rden_i and cpu_cs_bitmaps;
   cpu_wren_conf_stat <= cpu_wren_i and cpu_cs_conf_stat;
   cpu_rden_conf_stat <= cpu_rden_i and cpu_cs_conf_stat;


   --=====================================================
   -- VGA Clock Domain
   --=====================================================

   -----------------------------
   -- Instantiate the Sync block
   -----------------------------

   -- This generates the VGA timing signals
   inst_vga_sync : entity work.sync
   port map (
      clk_i    => vga_clk_i,

      hs_o     => vga_sync_hs,
      vs_o     => vga_sync_vs,
      hcount_o => vga_sync_hcount,
      vcount_o => vga_sync_vcount,
      blank_o  => vga_sync_blank
   );


   ---------------------------------------
   -- Instantiate the Character Font block 
   ---------------------------------------

   inst_vga_font : entity work.rom_file
   generic map (
                  G_RD_CLK_RIS => true,
                  G_ADDR_SIZE  => 12,
                  G_DATA_SIZE  => 8,
                  G_ROM_FILE   => G_FONT_FILE 
               )
   port map (
               clk_i  => vga_clk_i,
               addr_i => vga_char_font_addr,
               rden_i => '1',
               data_o => vga_char_font_data
            );


   --------------------------------------------
   -- Instantiate the Character Display memory
   --------------------------------------------

   inst_vga_char_disp_mem : entity work.mem
   generic map (
                  G_ADDR_SIZE => 10,  -- Size = 0x0400
                  G_DATA_SIZE => 8,
                  G_INIT_VAL  => 32   -- 0x20 = space
               )
   port map (
      -- Port A @ cpu_clk_i
      a_clk_i    => cpu_clk_i,
      a_addr_i   => cpu_addr_i(9 downto 0),
      --
      a_wren_i   => cpu_wren_chars,
      a_wrdata_i => cpu_data_i,
      --
      a_rden_i   => cpu_rden_chars,
      a_rddata_o => cpu_rddata_chars,

      -- Port B @ vga_clk_i
      b_clk_i   => vga_clk_i,
      b_addr_i  => vga_char_disp_addr,
      b_rden_i  => '1',
      b_data_o  => vga_char_disp_data
   );


   ------------------------------------------
   -- Instantiate the Character Display block
   ------------------------------------------

   -- This controls the display
   inst_vga_chars : entity work.chars
   port map (
      clk_i       => vga_clk_i,

      hcount_i    => vga_sync_hcount,
      vcount_i    => vga_sync_vcount,
      hsync_i     => vga_sync_hs,
      vsync_i     => vga_sync_vs,
      blank_i     => vga_sync_blank,

      config_i    => vga_config,
      status_i    => vga_status,
      keyboard_i  => vga_keyboard_debug,

      disp_addr_o => vga_char_disp_addr,
      disp_data_i => vga_char_disp_data,

      font_addr_o => vga_char_font_addr,
      font_data_i => vga_char_font_data,

      hcount_o    => vga_char_hcount,
      vcount_o    => vga_char_vcount,
      hsync_o     => vga_char_hs,
      vsync_o     => vga_char_vs,
      col_o       => vga_char_col
   );


   ---------------------------------------
   -- Instantiate the Sprite Bitmap memory
   ---------------------------------------

   inst_bitmaps_mem : entity work.bitmaps_mem
   port map (
      -- Read port @ vga_clk_i
      vga_clk_i   => vga_clk_i,
      vga_addr_i  => vga_bitmap_addr,
      vga_data_o  => vga_bitmap_data,

      -- Write port @ cpu_clk_i
      cpu_clk_i   => cpu_clk_i,
      cpu_addr_i  => cpu_addr_i(8 downto 0),
      cpu_wren_i  => cpu_wren_bitmaps,
      cpu_data_i  => cpu_data_i,
      cpu_rden_i  => cpu_rden_bitmaps,
      cpu_data_o  => cpu_rddata_bitmaps
   );


   ---------------------------------------
   -- Instantiate the Sprite Display block
   ---------------------------------------

   inst_vga_sprites : entity work.sprites
   port map (
      clk_i         => vga_clk_i,

      hcount_i      => vga_char_hcount,
      vcount_i      => vga_char_vcount,
      hs_i          => vga_char_hs,
      vs_i          => vga_char_vs,
      col_i         => vga_char_col,

      config_i      => vga_config,
      bitmap_addr_o => vga_bitmap_addr,
      bitmap_data_i => vga_bitmap_data,

      hcount_o      => vga_sprite_hcount,
      vcount_o      => vga_sprite_vcount,
      hs_o          => vga_sprite_hs,
      vs_o          => vga_sprite_vs,
      col_o         => vga_sprite_col
   );

   debug_o <=  vga_config(23 downto 16);

   -----------------------
   -- Drive output signals
   -----------------------

   vga_hs_o  <= vga_sprite_hs;
   vga_vs_o  <= vga_sprite_vs;
   vga_col_o <= vga_sprite_col;


   --=====================================================
   -- CPU and VGA Clock Domain Crossing
   --=====================================================

   -- Generate IRQ at end of a particular line, i.e. 60 times pr. second.
   -- This is a single clock pulse.
   vga_sync <= '1' when vga_char_hcount = FRAME_WIDTH and
               vga_char_vcount(10 downto 1) = vga_config(65*8 + 7 downto 65*8) else '0';


   -- Synchronize Sync pulse
   -- from VGA to CPU clock domain.
   inst_cdc_sync : entity work.cdcpulse
   port map (
      -- The sender
      rx_clk_i => vga_clk_i,
      rx_in_i  => vga_sync,

      -- The receiver
      tx_clk_i => cpu_clk_i,
      tx_out_o => cpu_sync
   );

   -- Synchronize CPU status information
   -- from CPU to VGA clock domain.
   inst_cdc_status : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 128
   )
   port map (
      -- The sender
      rx_clk_i => cpu_clk_i,
      rx_in_i  => cpu_status_i,

      -- The receiver
      tx_clk_i => vga_clk_i,
      tx_out_o => vga_status
   );

   -- Synchronize keyboard fifo
   -- from CPU to VGA clock domain.
   inst_cdc_keyboard : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 70
   )
   port map (
      -- The sender
      rx_clk_i => cpu_clk_i,
      rx_in_i  => cpu_keyboard_debug_i,

      -- The receiver
      tx_clk_i => vga_clk_i,
      tx_out_o => vga_keyboard_debug
   );


   -- Synchronize Sprite configuration data
   -- from CPU to VGA clock domain.
   inst_cdc_config : entity work.cdcvector
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_SIZE      => 128*8
   )
   port map (
      -- The sender
      rx_clk_i => cpu_clk_i,
      rx_in_i  => cpu_config,

      -- The receiver
      tx_clk_i => vga_clk_i,
      tx_out_o => vga_config
   );


   ---------------------------------------------
   -- Instantiate the Configure and Status block
   ---------------------------------------------

   inst_conf_stat : entity work.conf_stat
   port map (
      clk_i   => cpu_clk_i,
      rst_i   => cpu_rst_i,
      addr_i  => cpu_addr_i(8 downto 0),
      --
      wren_i  => cpu_wren_conf_stat,
      data_i  => cpu_data_i,
      --
      rden_i  => cpu_rden_conf_stat,
      data_o  => cpu_rddata_conf_stat,
      --
      config_o => cpu_config,
      --
      sync_i     => cpu_sync,
      irq_o      => cpu_irq_o,
      key_rden_o => cpu_key_rden_o,
      key_val_i  => cpu_key_val_i  
   );


   -----------------------------------
   -- Drive output signals to CPU port
   -----------------------------------

   cpu_data_o <= cpu_rddata_chars     when cpu_rden_chars     = '1' else
                 cpu_rddata_bitmaps   when cpu_rden_bitmaps   = '1' else
                 cpu_rddata_conf_stat when cpu_rden_conf_stat = '1' else
                 (others => '0');

end Structural;

