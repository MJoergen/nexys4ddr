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
      G_NEXYS4DDR  : boolean;          -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   : integer;          -- Number of bits in ROM address
      G_RAM_SIZE   : integer;          -- Number of bits in RAM address
      G_ROM_FILE   : string;           -- Contains the machine code
      G_FONT_FILE  : string            -- Contains the character font
   );
   port (
      -- Clocks and resets
      cpu_clk_i  : in  std_logic;
      vga_clk_i  : in  std_logic;   -- 25 MHz for a 640x480 display.
      cpu_rst_i  : in  std_logic;
      -- The VGA port does not need a reset.

      -- Keyboard / mouse
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Output LEDs
      led_o      : out std_logic_vector( 7 downto 0);

      -- Debug info from Ethernet PHY
      eth_debug_i : in std_logic_vector(511 downto 0);

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

   -- Address Decoding
   signal cpu_cs_rom   : std_logic;
   signal cpu_cs_vga   : std_logic;
   signal cpu_cs_ram   : std_logic;
   signal cpu_wren_vga : std_logic;
   signal cpu_rden_vga : std_logic;
   signal cpu_wren_ram : std_logic;
   signal cpu_rden_ram : std_logic;
   signal cpu_rden_rom : std_logic;

   -- Signals connected to the CPU.
   signal cpu_addr    : std_logic_vector(15 downto 0);
   signal cpu_wren    : std_logic;
   signal cpu_wrdata  : std_logic_vector(7 downto 0);
   signal cpu_rden    : std_logic;
   signal cpu_rddata  : std_logic_vector(7 downto 0);
   signal cpu_irq_vga : std_logic;
   signal cpu_debug   : std_logic_vector(127 downto 0);
   signal cpu_invalid : std_logic;

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
   -- Instantiate Address Decoding
   -------------------------------

   -- The RAM is placed at address 0x0000 and upwards.
   -- The ROM is placed at address 0xFFFF and downwards.
   -- The VGA is placed at address 0x8000 - 0x87FF
   inst_cs : entity work.cs
   generic map (
      G_ROM_SIZE => G_ROM_SIZE,
      G_RAM_SIZE => G_RAM_SIZE
   )
   port map (
      addr_i => cpu_addr,
      rom_o  => cpu_cs_rom,
      vga_o  => cpu_cs_vga,
      ram_o  => cpu_cs_ram
   );

   cpu_wren_vga <= cpu_wren and cpu_cs_vga;
   cpu_rden_vga <= cpu_rden and cpu_cs_vga;
   cpu_wren_ram <= cpu_wren and cpu_cs_ram; 
   cpu_rden_ram <= cpu_rden and cpu_cs_ram; 
   cpu_rden_rom <= cpu_rden and cpu_cs_rom; 

   cpu_rddata <= cpu_rddata_rom when cpu_rden_rom = '1' else
                 cpu_rddata_ram when cpu_rden_ram = '1' else
                 cpu_rddata_vga when cpu_rden_vga = '1' else
                 (others => '0');


   -------------------------
   -- Instantiate VGA module
   -------------------------

   inst_vga_module : entity work.vga_module
   generic map (
                  G_NEXYS4DDR => G_NEXYS4DDR,
                  G_FONT_FILE => G_FONT_FILE
               )
   port map (
      -- VGA Port
      vga_clk_i    => vga_clk_i,
      vga_hs_o     => vga_hs_o,
      vga_vs_o     => vga_vs_o,
      vga_col_o    => vga_col_o,
      vga_hcount_o => vga_hcount_o,
      vga_vcount_o => vga_vcount_o,

      -- CPU Port
      cpu_clk_i      => cpu_clk_i,
      cpu_rst_i      => cpu_rst_i,
      cpu_addr_i     => cpu_addr(10 downto 0),   -- 11 bit = 0x0800 size.
      cpu_rden_i     => cpu_rden_vga,
      cpu_data_o     => cpu_rddata_vga,
      cpu_wren_i     => cpu_wren_vga,
      cpu_data_i     => cpu_wrdata,
      cpu_irq_o      => cpu_irq_vga,
      cpu_status_i   => cpu_debug,
      cpu_key_rden_o => cpu_key_rden,
      cpu_key_val_i  => cpu_key_val,
      cpu_keyboard_debug_i => cpu_keyboard_debug,

      eth_debug_i    => eth_debug_i,
      debug_o        => open
   );


   ------------------------------
   -- Instantiate ROM
   ------------------------------

   inst_rom : entity work.rom_file
   generic map (
                  G_RD_CLK_RIS => false,        -- Read on falling clock edge
                  G_ADDR_SIZE  => G_ROM_SIZE,
                  G_DATA_SIZE  => 8,
                  G_ROM_FILE   => G_ROM_FILE
   )
   port map (
      clk_i  => cpu_clk_i,
      addr_i => cpu_addr(G_ROM_SIZE-1 downto 0),
      --
      rden_i => cpu_rden_rom,
      data_o => cpu_rddata_rom
   );


   ------------------------------
   -- Instantiate RAM
   ------------------------------

   inst_ram : entity work.mem
   generic map (
      G_ADDR_SIZE  => G_RAM_SIZE,
      G_DATA_SIZE  => 8
   )
   port map (
      a_clk_i    => cpu_clk_i,
      a_addr_i   => cpu_addr(G_RAM_SIZE-1 downto 0),
      --
      a_wren_i   => cpu_wren_ram,
      a_wrdata_i => cpu_wrdata,
      --
      a_rden_i   => cpu_rden_ram,
      a_rddata_o => cpu_rddata_ram

      -- Port B is not used
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

