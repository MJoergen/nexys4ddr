---------------------------------------------------------------------------------
-- This is the top level VGA module, and generates a 640 x 480 pixel screen.
--
-- The screen contains (in the following order, from background to foreground):
-- * 40x18 character display, taken from external 1K memory.
-- * Overlay of debug information, see below.
-- * Four 16x16 MOB's (aka sprites).
--
-- The debug information comes from the following inputs:
-- * status_i : This shows the internal CPU state, including registers, current
--              instruction, etc. A total of 8 rows of 4 hex characters.
-- * debug_i  : This shows another 8 rows of 4 hex characters.
--
-- Configuration information is provided in the config_i signal, and includes
-- * 0x00-0x07 X-position (2 bytes pr MOB)
-- * 0x08-0x0B Y-position (1 byte pr MOB)
-- * 0x0C-0x0F Color      (1 byte pr MOB)
-- * 0x10-0x13 Enable     (1 byte pr MOB)
-- * 0x18 Foreground text colour
-- * 0x19 Background text colour
-- * 0x1A Horizontal pixel shift
-- * 0x1B Y-line interrupt
-- * 0x1C IRQ status
-- * 0x1D IRQ mask
--
-- Interrupt is level-asserted, whenever the current line number matches the
-- value of 0x1B.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity vga_module is
   generic (
      G_NEXYS4DDR : boolean
   );
   port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      --
      hs_o        : out std_logic; 
      vs_o        : out std_logic;
      col_o       : out std_logic_vector(  7 downto 0);
      hcount_o    : out std_logic_vector( 10 downto 0);
      vcount_o    : out std_logic_vector( 10 downto 0);
      collision_o : out std_logic_vector(  3 downto 0);
      --
      font_addr_o : out std_logic_vector( 11 downto 0);
      font_data_i : in  std_logic_vector(  7 downto 0);
      disp_addr_o : out std_logic_vector(  9 downto 0);
      disp_data_i : in  std_logic_vector(  7 downto 0);
      col_addr_o  : out std_logic_vector(  9 downto 0);
      col_data_i  : in  std_logic_vector(  7 downto 0);
      mob_addr_o  : out std_logic_vector(  5 downto 0);
      mob_data_i  : in  std_logic_vector( 15 downto 0);
      --
      config_i    : in  std_logic_vector(32*8-1 downto 0);
      --
      -- The following signals are synchronized within this module,
      -- and need therefore not be synchronous to the clock domain.
      overlay_i      : in  std_logic;
      async_status_i : in  std_logic_vector(127 downto 0);
      async_debug_i  : in  std_logic_vector(255 downto 0)
   );
end vga_module;

architecture Structural of vga_module is
   
   -- Signals driven by the Sync block
   signal sync_hs     : std_logic; 
   signal sync_vs     : std_logic;
   signal sync_hcount : std_logic_vector(10 downto 0);
   signal sync_vcount : std_logic_vector(10 downto 0);
   signal sync_blank  : std_logic;

   -- Signals driven by the Character Display block
   signal char_hs     : std_logic; 
   signal char_vs     : std_logic;
   signal char_blank  : std_logic;
   signal char_hcount : std_logic_vector(10 downto 0);
   signal char_vcount : std_logic_vector(10 downto 0);
   signal char_col    : std_logic_vector( 7 downto 0);

   -- Signals driven by the Sprite Display block
   signal sprite_hs        : std_logic; 
   signal sprite_vs        : std_logic;
   signal sprite_blank     : std_logic;
   signal sprite_hcount    : std_logic_vector(10 downto 0);
   signal sprite_vcount    : std_logic_vector(10 downto 0);
   signal sprite_col       : std_logic_vector( 7 downto 0);
   signal sprite_collision : std_logic_vector( 3 downto 0);

   constant C_YINT : integer := 27;

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
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR
   )
   port map (
      clk_i       => clk_i,

      hcount_i    => sync_hcount,
      vcount_i    => sync_vcount,
      hsync_i     => sync_hs,
      vsync_i     => sync_vs,
      blank_i     => sync_blank,

      config_i    => config_i,

      overlay_i   => overlay_i,
      status_i    => async_status_i,
      debug_i     => async_debug_i,

      disp_addr_o => disp_addr_o,
      disp_data_i => disp_data_i,

      col_addr_o  => col_addr_o,
      col_data_i  => col_data_i,

      font_addr_o => font_addr_o,
      font_data_i => font_data_i,

      hcount_o    => char_hcount,
      vcount_o    => char_vcount,
      hsync_o     => char_hs,
      vsync_o     => char_vs,
      blank_o     => char_blank,
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
      blank_i       => char_blank,
      col_i         => char_col,

      config_i      => config_i,

      bitmap_addr_o => mob_addr_o,
      bitmap_data_i => mob_data_i,

      hcount_o      => sprite_hcount,
      vcount_o      => sprite_vcount,
      hs_o          => sprite_hs,
      vs_o          => sprite_vs,
      blank_o       => sprite_blank,
      col_o         => sprite_col,
      collision_o   => sprite_collision
   );

   -----------------------
   -- Drive output signals
   -----------------------

   hs_o        <= sprite_hs;
   vs_o        <= sprite_vs;
   col_o       <= sprite_col when sprite_blank = '0' else (others => '0');
   hcount_o    <= sprite_hcount;
   vcount_o    <= sprite_vcount;
   collision_o <= sprite_collision;

end Structural;

