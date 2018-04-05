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
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      hs_o     : out std_logic; 
      vs_o     : out std_logic;
      col_o    : out std_logic_vector(7 downto 0);
      hcount_o : out std_logic_vector(10 downto 0);
      vcount_o : out std_logic_vector(10 downto 0);
      font_addr_o : out std_logic_vector(11 downto 0);
      font_data_i : in  std_logic_vector( 7 downto 0);
      disp_addr_o : out std_logic_vector( 9 downto 0);
      disp_data_i : in  std_logic_vector( 7 downto 0);
      mob_addr_o  : out std_logic_vector( 5 downto 0);
      mob_data_i  : in  std_logic_vector(15 downto 0);

      eth_debug_i  : in std_logic_vector(511 downto 0);
      debug_o      : out std_logic_vector(7 downto 0)
   );
end vga_module;

architecture Structural of vga_module is
   
   -- These must be the same as defined in src/vga/sync.vhd
   constant FRAME_WIDTH  : natural := 640;
   constant FRAME_HEIGHT : natural := 480;

   -- Signals driven by the Sync block
   signal sync_hs     : std_logic; 
   signal sync_vs     : std_logic;
   signal sync_hcount : std_logic_vector(10 downto 0);
   signal sync_vcount : std_logic_vector(10 downto 0);
   signal sync_blank  : std_logic;

   -- Signals driven by the Character Display block
   signal char_hs     : std_logic; 
   signal char_vs     : std_logic;
   signal char_hcount : std_logic_vector(10 downto 0);
   signal char_vcount : std_logic_vector(10 downto 0);
   signal char_col    : std_logic_vector( 7 downto 0);
   --
   signal char_font_addr : std_logic_vector(11 downto 0);
   signal char_font_data : std_logic_vector( 7 downto 0);
   --
   signal char_disp_addr : std_logic_vector( 9 downto 0);
   signal char_disp_data : std_logic_vector( 7 downto 0);

   -- Signals driven by the Sprite Display block
   signal sprite_hs     : std_logic; 
   signal sprite_vs     : std_logic;
   signal sprite_hcount : std_logic_vector(10 downto 0);
   signal sprite_vcount : std_logic_vector(10 downto 0);
   signal sprite_col    : std_logic_vector( 7 downto 0);

   -- Signals driven by the Sprite Bitmap block
   signal bitmap_addr   : std_logic_vector( 5 downto 0);
   signal bitmap_data   : std_logic_vector(15 downto 0);

   -- Clock domain crossing
   signal config : std_logic_vector(128*8-1 downto 0) := (others => '0');
   signal status : std_logic_vector(127 downto 0) := (others => '0');
   signal keyboard_debug : std_logic_vector(69 downto 0) := (others => '0');

begin

   -----------------------------
   -- Instantiate the Sync block
   -----------------------------

   -- This generates the VGA timing signals
   inst_vga_sync : entity work.sync
   port map (
      clk_i    => clk_i,

      hs_o     => sync_hs,
      vs_o     => sync_vs,
      hcount_o => sync_hcount,
      vcount_o => sync_vcount,
      blank_o  => sync_blank
   );


   ------------------------------------------
   -- Instantiate the Character Display block
   ------------------------------------------

   -- This controls the display
   inst_vga_chars : entity work.chars
   port map (
      clk_i       => clk_i,

      hcount_i    => sync_hcount,
      vcount_i    => sync_vcount,
      hsync_i     => sync_hs,
      vsync_i     => sync_vs,
      blank_i     => sync_blank,

      config_i    => config,
      status_i    => status,
      keyboard_i  => keyboard_debug,
      eth_debug_i => eth_debug_i,

      disp_addr_o => disp_addr_o,
      disp_data_i => disp_data_i,

      font_addr_o => font_addr_o,
      font_data_i => font_data_i,

      hcount_o    => char_hcount,
      vcount_o    => char_vcount,
      hsync_o     => char_hs,
      vsync_o     => char_vs,
      col_o       => char_col
   );


   ---------------------------------------
   -- Instantiate the Sprite Display block
   ---------------------------------------

   inst_vga_sprites : entity work.sprites
   port map (
      clk_i         => clk_i,

      hcount_i      => char_hcount,
      vcount_i      => char_vcount,
      hs_i          => char_hs,
      vs_i          => char_vs,
      col_i         => char_col,

      config_i      => config,
      bitmap_addr_o => mob_addr_o,
      bitmap_data_i => mob_data_i,

      hcount_o      => sprite_hcount,
      vcount_o      => sprite_vcount,
      hs_o          => sprite_hs,
      vs_o          => sprite_vs,
      col_o         => sprite_col
   );

   debug_o <=  config(23 downto 16);

   -----------------------
   -- Drive output signals
   -----------------------

   hs_o     <= sprite_hs;
   vs_o     <= sprite_vs;
   col_o    <= sprite_col;
   hcount_o <= sprite_hcount;
   vcount_o <= sprite_vcount;

end Structural;

