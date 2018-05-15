library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This is the top level wrapper for the NEXYS4DDR board.
-- This is needed, because this design is meant to
-- work on both the BASYS2 and the NEXYS4DDR boards.
-- This file therefore contains all the stuff
-- particular to the NEXYS4DDR platform.

entity nexys4ddr is

   generic (
      G_RESET_SIZE : integer := 22;          -- Number of bits in reset counter.
      G_SIMULATION : boolean := false;
      G_DUT_MAC    : std_logic_vector(47 downto 0) := X"F46D04112233";
      G_DUT_IP     : std_logic_vector(31 downto 0) := X"C0A8012E";      -- 192.168.1.46
      G_DUT_PORT   : std_logic_vector(15 downto 0) := X"2345";          -- Port 9029
      G_HOST_MAC   : std_logic_vector(47 downto 0) := X"F46D04D7F3CA";
      G_HOST_IP    : std_logic_vector(31 downto 0) := X"C0A8012B";      -- 192.168.1.43
      G_HOST_PORT  : std_logic_vector(15 downto 0) := X"1234"           -- Port 4660
   );
   port (
      -- Clock. Connected to an external 100 MHz crystal.
      clk100_i     : in    std_logic;

      -- Reset. Asserted low.
      sys_rstn_i   : in    std_logic;

      -- Input switches and push buttons
      sw_i         : in    std_logic_vector(15 downto 0);
      btn_i        : in    std_logic_vector(4 downto 0);

      -- Keyboard / mouse
      ps2_clk_i    : in    std_logic;
      ps2_data_i   : in    std_logic;

      -- Output LEDs
      led_o        : out   std_logic_vector(15 downto 0);

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic;

      -- Output to VGA monitor
      vga_hs_o     : out   std_logic;
      vga_vs_o     : out   std_logic;
      vga_col_o    : out   std_logic_vector(11 downto 0)
   );
end nexys4ddr;

architecture Structural of nexys4ddr is

   -- Clocks and Reset
   signal vga_clk   : std_logic;
   signal vga_rst   : std_logic;
   signal cpu_clk   : std_logic;
   signal cpu_rst   : std_logic;
   signal cpu_step  : std_logic;
   signal eth_clk   : std_logic;
   signal eth_rst   : std_logic;
 
   -- VGA output
   signal vga_col    : std_logic_vector(7 downto 0);
   signal vga_hs     : std_logic;
   signal vga_vs     : std_logic;
   signal vga_hcount : std_logic_vector(10 downto 0);
   signal vga_vcount : std_logic_vector(10 downto 0);
   signal vga_debug  : std_logic_vector(255 downto 0);
 
   -- LED output
   signal led : std_logic;

   -- Convert colour from 8-bit format to 12-bit format
   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
      type t_dat is array (natural range <>) of std_logic_vector(3 downto 0);

      constant conv2_4 : t_dat :=
         ("0000", "0101", "1010", "1111");

      constant conv3_4 : t_dat :=
         ("0000", "0010", "0100", "0110", "1001", "1011", "1101", "1111");
   begin
      return conv3_4(conv_integer(arg(7 downto 5))) &
             conv3_4(conv_integer(arg(4 downto 2))) &
             conv2_4(conv_integer(arg(1 downto 0)));
   end function col8to12;

   signal eth_smi_registers : std_logic_vector(32*16-1 downto 0);
   signal eth_stat_debug    : std_logic_vector(6*16-1 downto 0);
   signal eth_debug         : std_logic_vector(255 downto 0);
   signal fifo_error        : std_logic := '0';

   -- Memory data received from Ethernet @ cpu_clk
   signal cpu_wr_addr  : std_logic_vector(15 downto 0);
   signal cpu_wr_en    : std_logic;
   signal cpu_wr_data  : std_logic_vector(7 downto 0);
   signal cpu_reset    : std_logic;
   signal cpu_hack_rst : std_logic;

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------

   inst_clk_rst : entity work.clk_rst
   generic map (
      G_NEXYS4DDR  => true,
      G_RESET_SIZE => G_RESET_SIZE,
      G_SIMULATION => G_SIMULATION
   )
   port map (
      sys_clk100_i => clk100_i,
      sys_rstn_i   => sys_rstn_i,
      sys_step_i   => btn_i(0),
      sys_mode_i   => sw_i(0),
      vga_clk_o    => vga_clk,
      vga_rst_o    => vga_rst,
      cpu_clk_o    => cpu_clk,
      cpu_rst_o    => cpu_rst,
      cpu_step_o   => cpu_step,
      eth_clk_o    => eth_clk,
      eth_rst_o    => eth_rst
   );


   ------------------------------
   -- Ethernet port wrapper
   ------------------------------
   inst_ethernet : entity work.ethernet
   generic map (
      G_DUT_MAC   => G_DUT_MAC,
      G_DUT_IP    => G_DUT_IP,
      G_DUT_PORT  => G_DUT_PORT,
      G_HOST_MAC  => G_HOST_MAC,
      G_HOST_IP   => G_HOST_IP,
      G_HOST_PORT => G_HOST_PORT
   )
   port map (
      eth_clk_i           => eth_clk,
      eth_rst_i           => eth_rst,
      eth_txd_o           => eth_txd_o,
      eth_txen_o          => eth_txen_o,
      eth_rxd_i           => eth_rxd_i,
      eth_rxerr_i         => eth_rxerr_i,
      eth_crsdv_i         => eth_crsdv_i,
      eth_intn_i          => eth_intn_i,
      eth_mdio_io         => eth_mdio_io,
      eth_mdc_o           => eth_mdc_o,
      eth_rstn_o          => eth_rstn_o,
      eth_refclk_o        => eth_refclk_o,
      vga_clk_i           => vga_clk,
      vga_rst_i           => vga_rst,
      vga_col_i           => vga_col,
      vga_hs_i            => vga_hs,
      vga_vs_i            => vga_vs,
      vga_hcount_i        => vga_hcount,
      vga_vcount_i        => vga_vcount,
      vga_transmit_i      => sw_i(8),
      cpu_clk_i           => cpu_clk,
      cpu_rst_i           => cpu_rst,
      cpu_wr_addr_o       => cpu_wr_addr,
      cpu_wr_en_o         => cpu_wr_en,
      cpu_wr_data_o       => cpu_wr_data,
      cpu_reset_o         => cpu_reset,
      eth_smi_registers_o => eth_smi_registers,
      eth_stat_debug_o    => eth_stat_debug
   );


   cpu_hack_rst <= cpu_rst or cpu_reset;

   ------------------------------
   -- Hack Computer!
   ------------------------------

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR => true,               -- True, when using the Nexys4DDR board.
      G_ROM_SIZE  => 11,                 -- Number of bits in ROM address
      G_RAM_SIZE  => 11,                 -- Number of bits in RAM address
      G_DISP_SIZE => 10,                 -- Number of bits in DISP address
      G_COL_SIZE  => 10,                 -- Number of bits in COL address
      G_FONT_SIZE => 12,                 -- Number of bits in FONT address
      G_MOB_SIZE  => 7,                  -- Number of bits in MOB address
      G_CONF_SIZE => 5,                  -- Number of bits in CONF address
      G_RAM_MASK  => X"0000",            -- Last address 0x07FF
      G_DISP_MASK => X"8000",            -- Last address 0x83FF
      G_COL_MASK  => X"8800",            -- Last address 0x8BFF
      G_MOB_MASK  => X"8400",            -- Last address 0x847F
      G_CONF_MASK => X"8600",            -- Last address 0x861F
      G_FONT_MASK => X"9000",            -- Last address 0x9FFF
      G_ROM_MASK  => X"F800",            -- Last address 0xFFFF
      G_ROM_FILE  => "rom.txt",          -- Contains the machine code
      G_FONT_FILE => "ProggyClean.txt"   -- Contains the character font
   )
   port map (
      cpu_clk_i     => cpu_clk,
      cpu_rst_i     => cpu_hack_rst,
      cpu_step_i    => cpu_step,
      cpu_wr_addr_i => cpu_wr_addr,
      cpu_wr_en_i   => cpu_wr_en,
      cpu_wr_data_i => cpu_wr_data,
      cpu_led_o     => led_o(7 downto 0),
      --
      vga_clk_i     => vga_clk,
      vga_rst_i     => vga_rst,
      vga_hs_o      => vga_hs,
      vga_vs_o      => vga_vs,
      vga_col_o     => vga_col,
      vga_hcount_o  => vga_hcount,
      vga_vcount_o  => vga_vcount,
      vga_overlay_i => sw_i(3 downto 1),
      vga_debug_i   => vga_debug,
      --
      ps2_clk_i     => ps2_clk_i,
      ps2_data_i    => ps2_data_i
   );
 
   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= col8to12(vga_col);
   led_o(15 downto 8) <= (others => '0');

   eth_debug(6*16-1 downto 0)     <= eth_stat_debug;
   eth_debug(16*16-1 downto 6*16) <= (others => '0');
   
   vga_debug <= eth_smi_registers(255 downto 0) when sw_i(4) = '1' else
                eth_debug;

end Structural;

