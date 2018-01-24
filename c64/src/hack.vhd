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
-- domain, i.e. cpu_ or vga_.

entity hack is

   generic (
      G_ROM_SIZE   : integer := 10;                -- Number of bits in ROM address
      G_RAM_SIZE   : integer := 10;                -- Number of bits in RAM address
      G_SIMULATION : boolean := false;
      G_ROM_FILE   : string  := "rom.txt";         -- Contains the machine code
      G_FONT_FILE  : string  := "ProggyClean.txt"  -- Contains the character font
   );
   port (
      -- Clock
      sys_clk_i  : in  std_logic;  -- 100 MHz on the Nexys4DDR board.

      -- Reset
      sys_rstn_i : in  std_logic;  -- Asserted low

      -- Input switches and push buttons
      sw_i       : in  std_logic_vector(15 downto 0);
      btn_i      : in  std_logic_vector( 4 downto 0);

      -- Output LEDs
      led_o      : out std_logic_vector(15 downto 0);

     -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0)
  );

end hack;

architecture Structural of hack is

   -------------------
   -- CPU clock domain
   -------------------

   -- Clocks and Reset
   signal cpu_clk   : std_logic;
   signal cpu_rst   : std_logic;
   
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

   -- Signals driven by other blocks
   signal cpu_rddata_rom : std_logic_vector(7 downto 0);
   signal cpu_rddata_ram : std_logic_vector(7 downto 0);
   signal cpu_rddata_vga : std_logic_vector(7 downto 0);


   -------------------
   -- VGA clock domain
   -------------------

   signal vga_clk   : std_logic;
   signal vga_rst   : std_logic;


begin

   ------------------------------
   -- Instantiate Clock and Reset
   ------------------------------

   inst_clk_rst : entity work.clk_rst
   generic map (
      G_SIMULATION => G_SIMULATION
   )
   port map (
      sys_clk_i  => sys_clk_i,
      sys_rstn_i => sys_rstn_i,
      cpu_rst_o  => cpu_rst,
      vga_rst_o  => vga_rst,
      cpu_clk_o  => cpu_clk,
      vga_clk_o  => vga_clk
   );


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


   ------------------------------
   -- Instantiate VGA module (only during synthesis)
   ------------------------------

   gen_vga: if true generate -- G_SIMULATION = false  generate
      inst_vga_module : entity work.vga_module
      generic map (
                     G_FONT_FILE  => G_FONT_FILE
                  )
      port map (
         -- VGA Port
         vga_clk_i => vga_clk,
         vga_rst_i => vga_rst,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o,

         -- CPU Port
         cpu_clk_i    => cpu_clk,
         cpu_rst_i    => cpu_rst,
         cpu_addr_i   => cpu_addr(10 downto 0),   -- 11 bit = 0x0800 size.
         cpu_rden_i   => cpu_rden_vga,
         cpu_data_o   => cpu_rddata_vga,
         cpu_wren_i   => cpu_wren_vga,
         cpu_data_i   => cpu_wrdata,
         cpu_irq_o    => cpu_irq_vga,
         cpu_status_i => cpu_debug,

         debug_o      => led_o(15 downto 8)
      );
   end generate gen_vga;

   led_o(7 downto 0) <= (others => '0');

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
      clk_i  => cpu_clk,
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
      a_clk_i    => cpu_clk,
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
      clk_i   => cpu_clk,
      rst_i   => cpu_rst,

      addr_o  => cpu_addr,

      rden_o  => cpu_rden,
      data_i  => cpu_rddata,

      wren_o  => cpu_wren,
      data_o  => cpu_wrdata,

      irq_i   => cpu_irq_vga,
      debug_o => cpu_debug 
   );


   -- Dump Program Counter to LED's
   --led_o <= cpu_debug(47 downto 32);

end Structural;

