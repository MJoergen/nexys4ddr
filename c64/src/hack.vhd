library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level instance of this "computer".
-- It consists of four blocks:
-- 1) The CPU controlling everything
-- 2) The VGA module
-- 3) The memory module (containing ROM and RAM)
-- 4) The Keyboard module (PS2 interface)
-- 
-- A note on naming convention: Since this design uses two asynchronuous clock
-- domains, all signal names are prefixed with the corresponding clock
-- domain, i.e. cpu_ or vga_. Signals without this prefix are considered asynchronous
-- and therefore require synchronization before being used.

entity hack is

   generic (
      G_NEXYS4DDR : boolean;          -- True, when using the Nexys4DDR board.
      G_ROM_SIZE  : integer;          -- Number of bits in ROM address
      G_RAM_SIZE  : integer;          -- Number of bits in RAM address
      G_DISP_SIZE : integer;          -- Number of bits in DISP address
      G_COL_SIZE  : integer;          -- Number of bits in COL address
      G_FONT_SIZE : integer;          -- Number of bits in FONT address
      G_MOB_SIZE  : integer;          -- Number of bits in MOB address
      G_CONF_SIZE : integer;          -- Number of bits in CONF address
      G_ROM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in ROM address
      G_RAM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in RAM address
      G_DISP_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in DISP address
      G_COL_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in COL address
      G_FONT_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in FONT address
      G_MOB_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in MOB address
      G_CONF_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in CONF address
      G_ROM_FILE  : string;           -- Contains the contents of the ROM memory.
      G_FONT_FILE : string            -- Contains the contents of the FONT memory.
   );
   port (
      -- Clocks and resets
      cpu_clk_i     : in  std_logic;
      cpu_rst_i     : in  std_logic;
      cpu_step_i    : in  std_logic;
      -- ROM data received from Ethernet
      cpu_wr_addr_i : in  std_logic_vector(15 downto 0) := (others => '0');
      cpu_wr_en_i   : in  std_logic                     := '0';
      cpu_wr_data_i : in  std_logic_vector( 7 downto 0) := (others => '0');
      -- Output LEDs
      cpu_led_o     : out std_logic_vector( 7 downto 0);

      vga_clk_i     : in  std_logic;
      vga_rst_i     : in  std_logic;
      -- Debug info
      vga_overlay_i : in std_logic_vector(2 downto 0);
      vga_debug_i   : in std_logic_vector(255 downto 0);
      -- Output to VGA monitor
      vga_hs_o      : out std_logic;
      vga_vs_o      : out std_logic;
      vga_col_o     : out std_logic_vector( 7 downto 0);
      vga_hcount_o  : out std_logic_vector(10 downto 0);
      vga_vcount_o  : out std_logic_vector(10 downto 0);

      -- Keyboard / mouse
      ps2_clk_i     : in  std_logic;
      ps2_data_i    : in  std_logic
   );
end hack;

architecture Structural of hack is

   -- Signals connected to the CPU.
   signal cpu_addr    : std_logic_vector(15 downto 0);
   signal cpu_wren    : std_logic;
   signal cpu_wrdata  : std_logic_vector(7 downto 0);
   signal cpu_rden    : std_logic;
   signal cpu_rddata  : std_logic_vector(7 downto 0);
   signal cpu_irq     : std_logic;
   signal cpu_status  : std_logic_vector(127 downto 0);
   signal cpu_invalid : std_logic_vector(7 downto 0);
   signal cpu_wait    : std_logic;

   -- Signals connected to the MEM
   signal mem_addr    : std_logic_vector(15 downto 0);
   signal mem_wren    : std_logic;
   signal mem_wrdata  : std_logic_vector(7 downto 0);
   signal mem_wait    : std_logic;

   -- Signals connected to the VGA.
   signal vga_font_addr : std_logic_vector(11 downto 0);
   signal vga_font_data : std_logic_vector( 7 downto 0);
   signal vga_disp_addr : std_logic_vector( 9 downto 0);
   signal vga_disp_data : std_logic_vector( 7 downto 0);
   signal vga_col_addr  : std_logic_vector( 9 downto 0);
   signal vga_col_data  : std_logic_vector( 7 downto 0);
   signal vga_mob_addr  : std_logic_vector( 5 downto 0);
   signal vga_mob_data  : std_logic_vector(15 downto 0);
   signal vga_config    : std_logic_vector(32*8-1 downto 0);
   signal vga_hs        : std_logic;
   signal vga_vs        : std_logic;
   signal vga_col       : std_logic_vector( 7 downto 0);
   signal vga_hcount    : std_logic_vector(10 downto 0);
   signal vga_vcount    : std_logic_vector(10 downto 0);
   signal vga_collision : std_logic_vector( 3 downto 0);
   signal vga_debug     : std_logic_vector(255 downto 0);

   -- Signals connected to the keyboard
   signal cpu_key_rden  : std_logic;
   signal cpu_key_val   : std_logic_vector(7 downto 0);
   signal cpu_key_debug : std_logic_vector(255 downto 0);

begin

   ------------------------------
   -- Instantiate CPU
   ------------------------------

   inst_cpu : entity work.cpu_module
   port map (
      clk_i     => cpu_clk_i,
      rst_i     => cpu_rst_i,
      step_i    => cpu_step_i,
      addr_o    => cpu_addr,
      rden_o    => cpu_rden,
      data_i    => cpu_rddata,
      wren_o    => cpu_wren,
      data_o    => cpu_wrdata,
      irq_i     => cpu_irq,
      wait_i    => mem_wait,
      invalid_o => cpu_invalid,
      status_o  => cpu_status
   );


   -------------------------
   -- Instantiate VGA module
   -------------------------

   inst_vga_module : entity work.vga_module
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR
   )
   port map (
      clk_i          => vga_clk_i,
      rst_i          => vga_rst_i,
      hs_o           => vga_hs,
      vs_o           => vga_vs,
      col_o          => vga_col,
      hcount_o       => vga_hcount,
      vcount_o       => vga_vcount,
      collision_o    => vga_collision,
      font_addr_o    => vga_font_addr,
      font_data_i    => vga_font_data,
      col_addr_o     => vga_col_addr,
      col_data_i     => vga_col_data,
      disp_addr_o    => vga_disp_addr,
      disp_data_i    => vga_disp_data,
      mob_addr_o     => vga_mob_addr,
      mob_data_i     => vga_mob_data,
      config_i       => vga_config,
      overlay_i      => vga_overlay_i(0),
      async_debug_i  => vga_debug,
      async_status_i => cpu_status
   );

   vga_debug <= vga_config(255 downto 0) when vga_overlay_i(2) = '1' else
                cpu_key_debug            when vga_overlay_i(1) = '1' else
                vga_debug_i;

   vga_hs_o     <= vga_hs;
   vga_vs_o     <= vga_vs;
   vga_col_o    <= vga_col;
   vga_hcount_o <= vga_hcount;
   vga_vcount_o <= vga_vcount;


   -------------------------------
   -- Instantiate multiplexer
   -------------------------------

   inst_addr_mux : entity work.addr_mux
   port map (
      lo_addr_i     => cpu_addr,
      lo_wr_en_i    => cpu_wren,
      lo_wr_data_i  => cpu_wrdata,
      lo_wait_i     => cpu_wait,
      hi_addr_i     => cpu_wr_addr_i,
      hi_wr_en_i    => cpu_wr_en_i,
      hi_wr_data_i  => cpu_wr_data_i,
      hi_wait_i     => '1',
      res_addr_o    => mem_addr,
      res_wr_en_o   => mem_wren,
      res_wr_data_o => mem_wrdata,
      res_wait_o    => mem_wait
   );


   -------------------------------
   -- Instantiate memory
   -------------------------------

   inst_mem : entity work.mem_module
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_ROM_SIZE  => G_ROM_SIZE,
      G_RAM_SIZE  => G_RAM_SIZE,
      G_DISP_SIZE => G_DISP_SIZE,
      G_COL_SIZE  => G_COL_SIZE,
      G_FONT_SIZE => G_FONT_SIZE,
      G_MOB_SIZE  => G_MOB_SIZE,
      G_CONF_SIZE => G_CONF_SIZE,
      G_ROM_MASK  => G_ROM_MASK,
      G_RAM_MASK  => G_RAM_MASK,
      G_DISP_MASK => G_DISP_MASK,
      G_COL_MASK  => G_COL_MASK,
      G_FONT_MASK => G_FONT_MASK,
      G_MOB_MASK  => G_MOB_MASK,
      G_CONF_MASK => G_CONF_MASK,
      G_ROM_FILE  => G_ROM_FILE,
      G_FONT_FILE => G_FONT_FILE 
   )
   port map (
      -- Port A (Write and Read)
      a_clk_i     => cpu_clk_i,
      a_rst_i     => cpu_rst_i,
      a_addr_i    => mem_addr,
      a_wren_i    => mem_wren,
      a_data_i    => mem_wrdata,
      a_rden_i    => cpu_rden,
      a_data_o    => cpu_rddata,
      a_wait_o    => cpu_wait,
      a_irq_o     => cpu_irq,
      a_kb_rden_o => cpu_key_rden,
      a_kb_val_i  => cpu_key_val,

      -- Port B (Read only)
      b_clk_i       => vga_clk_i,
      b_rst_i       => vga_rst_i,
      b_disp_addr_i => vga_disp_addr,
      b_disp_data_o => vga_disp_data,
      b_col_addr_i  => vga_col_addr,
      b_col_data_o  => vga_col_data,
      b_font_addr_i => vga_font_addr,
      b_font_data_o => vga_font_data,
      b_mob_addr_i  => vga_mob_addr,
      b_mob_data_o  => vga_mob_data,
      b_config_o    => vga_config,
      b_collision_i => vga_collision,
      b_vcount_i    => vga_vcount,
      b_hcount_i    => vga_hcount
  );


   ---------------------------
   -- Instantiate the keyboard
   ---------------------------
   inst_keyboard : entity work.keyboard
   port map (
      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,
      clk_i      => cpu_clk_i,
      rst_i      => cpu_rst_i,
      rden_i     => cpu_key_rden,
      val_o      => cpu_key_val,
      debug_o    => cpu_key_debug(69 downto 0)
   );

   cpu_led_o <= cpu_invalid;

end Structural;

