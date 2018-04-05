library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level instance of this "computer".
-- It consists of four blocks:
-- 1) The CPU controlling everything
-- 2) The ROM (containing the machine code)
-- 3) The VGA module (memory mapped)
-- 4) The RAM
-- 
-- The ROM, VGA, and RAM all respond upon read on the falling clock edge. This
-- "imitates" an asynchronous memory interface.
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
      G_FONT_SIZE : integer;          -- Number of bits in FONT address
      G_MOB_SIZE  : integer;          -- Number of bits in MOB address
      G_ROM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in ROM address
      G_RAM_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in RAM address
      G_DISP_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in DISP address
      G_FONT_MASK : std_logic_vector(15 downto 0);  -- Value of upper bits in FONT address
      G_MOB_MASK  : std_logic_vector(15 downto 0);  -- Value of upper bits in MOB address
      G_ROM_FILE  : string;           -- Contains the contents of the ROM memory.
      G_FONT_FILE : string            -- Contains the contents of the FONT memory.
   );
   port (
      -- Clocks and resets
      cpu_clk_i  : in  std_logic;
      vga_clk_i  : in  std_logic;   -- 25 MHz for a 640x480 display.
      cpu_rst_i  : in  std_logic;
      vga_rst_i  : in  std_logic;

      -- Keyboard / mouse
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Output LEDs
      led_o      : out std_logic_vector( 7 downto 0);

      -- Debug info from Ethernet PHY
      eth_debug_i : in std_logic_vector(511 downto 0);

      -- ROM data received from Ethernet
      cpu_pl_wr_addr_i : in  std_logic_vector(15 downto 0);
      cpu_pl_wr_en_i   : in  std_logic;
      cpu_pl_wr_data_i : in  std_logic_vector(7 downto 0);

      -- Output to VGA monitor
      vga_hs_o     : out std_logic;
      vga_vs_o     : out std_logic;
      vga_col_o    : out std_logic_vector( 7 downto 0);
      vga_hcount_o : out std_logic_vector(10 downto 0);
      vga_vcount_o : out std_logic_vector(10 downto 0)
  );

end hack;

architecture Structural of hack is

   -------------------
   -- CPU clock domain
   -------------------

   -- Signals connected to the CPU.
   signal cpu_addr    : std_logic_vector(15 downto 0);
   signal cpu_wren    : std_logic;
   signal cpu_wrdata  : std_logic_vector(7 downto 0);
   signal cpu_rden    : std_logic;
   signal cpu_rddata  : std_logic_vector(7 downto 0);
   signal cpu_irq_vga : std_logic;
   signal cpu_debug   : std_logic_vector(127 downto 0);
   signal cpu_invalid : std_logic;
   signal cpu_wait    : std_logic;

   -- Signals connected to the VGA.
   signal vga_font_addr : std_logic_vector(11 downto 0);
   signal vga_font_data : std_logic_vector( 7 downto 0);
   signal vga_disp_addr : std_logic_vector( 9 downto 0);
   signal vga_disp_data : std_logic_vector( 7 downto 0);
   signal vga_mob_addr  : std_logic_vector( 5 downto 0);
   signal vga_mob_data  : std_logic_vector(15 downto 0);

   -- Signals driven by other blocks
   signal cpu_rddata_rom : std_logic_vector(7 downto 0);
   signal cpu_rddata_ram : std_logic_vector(7 downto 0);
   signal cpu_rddata_vga : std_logic_vector(7 downto 0);

   -- Signals connected to the keyboard
   signal cpu_key_rden : std_logic;
   signal cpu_key_val  : std_logic_vector(7 downto 0);
   signal cpu_keyboard_debug : std_logic_vector(69 downto 0);

begin

   -------------------------------
   -- Instantiate memory
   -------------------------------

   inst_mem : entity work.mem_module
   generic map (
      G_NEXYS4DDR => G_NEXYS4DDR,
      G_ROM_SIZE  => G_ROM_SIZE,
      G_RAM_SIZE  => G_RAM_SIZE,
      G_DISP_SIZE => G_DISP_SIZE,
      G_FONT_SIZE => G_FONT_SIZE,
      G_MOB_SIZE  => G_MOB_SIZE,
      G_ROM_MASK  => G_ROM_MASK,
      G_RAM_MASK  => G_RAM_MASK,
      G_DISP_MASK => G_DISP_MASK,
      G_FONT_MASK => G_FONT_MASK,
      G_MOB_MASK  => G_MOB_MASK,
      G_ROM_FILE  => G_ROM_FILE,
      G_FONT_FILE => G_FONT_FILE 
   )
   port map (
      -- Port A (Write and Read)
      a_clk_i  => cpu_clk_i,
      a_rst_i  => cpu_rst_i,
      a_addr_i => cpu_addr,
      a_wren_i => cpu_wren,
      a_data_i => cpu_wrdata,
      a_rden_i => cpu_rden,
      a_data_o => cpu_rddata,
      a_wait_o => cpu_wait,

      -- Port B (Read only)
      b_clk_i       => vga_clk_i,
      b_rst_i       => vga_rst_i,
      b_disp_addr_i => vga_disp_addr,
      b_disp_data_o => vga_disp_data,
      b_font_addr_i => vga_font_addr,
      b_font_data_o => vga_font_data,
      b_mob_addr_i  => vga_mob_addr,
      b_mob_data_o  => vga_mob_data
  );


   -------------------------
   -- Instantiate VGA module
   -------------------------

   inst_vga_module : entity work.vga_module
   generic map (
                  G_NEXYS4DDR => G_NEXYS4DDR,
                  G_FONT_FILE => G_FONT_FILE
               )
   port map (
      clk_i       => vga_clk_i,
      rst_i       => vga_rst_i,
      hs_o        => vga_hs_o,
      vs_o        => vga_vs_o,
      col_o       => vga_col_o,
      hcount_o    => vga_hcount_o,
      vcount_o    => vga_vcount_o,
      font_addr_o => vga_font_addr,
      font_data_i => vga_font_data,
      disp_addr_o => vga_disp_addr,
      disp_data_i => vga_disp_data,
      mob_addr_o  => vga_mob_addr,
      mob_data_i  => vga_mob_data,

      eth_debug_i     => eth_debug_i,
      debug_o         => open
   );

   ------------------------------
   -- Instantiate CPU
   ------------------------------

   inst_cpu : entity work.cpu_module
   port map (
      clk_i   => cpu_clk_i,
      rst_i   => cpu_rst_i,

      addr_o  => cpu_addr,

      rden_o  => cpu_rden,
      data_i  => cpu_rddata,

      wren_o  => cpu_wren,
      data_o  => cpu_wrdata,

      irq_i   => cpu_irq_vga,
      invalid_o => cpu_invalid,
      debug_o => cpu_debug 
   );


   ---------------------------
   -- Instantiate the keyboard
   ---------------------------
   inst_keyboard : entity work.keyboard
   port map (
      clk_i      => cpu_clk_i,
      rst_i      => cpu_rst_i,

      ps2_clk_i  => ps2_clk_i,
      ps2_data_i => ps2_data_i,

      rden_i     => cpu_key_rden,
      val_o      => cpu_key_val,
      debug_o    => cpu_keyboard_debug
   );

   led_o <= (others => cpu_invalid);

end Structural;

