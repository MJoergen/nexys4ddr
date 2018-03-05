library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.Vcomponents.all;

-- This is the top level wrapper for the NEXYS4DDR board.
-- This is needed, because this design is meant to
-- work on both the BASYS2 and the NEXYS4DDR boards.
-- This file therefore contains all the stuff
-- peculiar to the NEXYS4DDR platform.

entity nexys4ddr is

   generic (
      G_RESET_SIZE : integer := 22;          -- Number of bits in reset counter.
      G_SIMULATION : boolean := false
   );
   port (
      -- Clock
      clk100_i   : in  std_logic;   -- This pin is connected to an external 100 MHz crystal.

      -- Reset
      sys_rstn_i : in  std_logic;   -- Asserted low

      -- Input switches and push buttons
      sw_i       : in  std_logic_vector(15 downto 0);
      btn_i      : in  std_logic_vector(4 downto 0);

      -- Keyboard / mouse
      ps2_clk_i  : in  std_logic;
      ps2_data_i : in  std_logic;

      -- Output LEDs
      led_o      : out std_logic_vector(15 downto 0);

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
      eth_refclk_o : out   std_logic;        -- Connected to XTAL1/CLKIN. Must be driven to 50 MHz.
                                             -- All RMII signals are syunchronous to this clock.

      -- Output to VGA monitor
      vga_hs_o   : out std_logic;
      vga_vs_o   : out std_logic;
      vga_col_o  : out std_logic_vector(11 downto 0)
   );
end nexys4ddr;

architecture Structural of nexys4ddr is

   -- Clocks and Reset
   signal vga_clk   : std_logic;
   signal vga_rst   : std_logic;
   signal cpu_clk   : std_logic;
   signal cpu_rst   : std_logic;
   signal eth_clk   : std_logic;
   signal eth_rst   : std_logic;
 
   -- VGA color output
   signal vga_col    : std_logic_vector(7 downto 0);
   signal vga_hs     : std_logic;
   signal vga_vs     : std_logic;
   signal vga_hcount : std_logic_vector(10 downto 0);
   signal vga_vcount : std_logic_vector(10 downto 0);
 
   -- LED output
   signal led : std_logic;

   -- Convert colour from 8-bit format to 12-bit format
   function col8to12(arg : std_logic_vector(7 downto 0)) return std_logic_vector is
   begin
      return arg(7 downto 5) & "0" & arg(4 downto 2) & "0" & arg(1 downto 0) & "00";
   end function col8to12;

   signal mac_tx_data  : std_logic_vector(7 downto 0) := X"AE";
   signal mac_tx_sof   : std_logic := '1';
   signal mac_tx_eof   : std_logic := '1';
   signal mac_tx_empty : std_logic := '0';
   signal mac_tx_rden  : std_logic := '0';

   signal mac_smi_ready    : std_logic;
   signal mac_smi_phy      : std_logic_vector(4 downto 0) := "00001"; -- Constant.
   signal mac_smi_addr     : std_logic_vector(4 downto 0) := "00000";
   signal mac_smi_rden     : std_logic := '0';
   signal mac_smi_data_out : std_logic_vector(15 downto 0);
   signal mac_smi_wren     : std_logic := '0';
   signal mac_smi_data_in  : std_logic_vector(15 downto 0);

   signal mac_smi_registers : std_logic_vector(32*16-1 downto 0) := (others => '0');

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------

   inst_clk_rst : entity work.clk_rst
   generic map (
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
      eth_clk_o    => eth_clk,
      eth_rst_o    => eth_rst
   );


   ------------------------------
   -- Read SMI from PHY
   ------------------------------

   proc_smi : process (eth_clk)
      variable state_v : std_logic_vector(1 downto 0);
   begin
      if rising_edge(eth_clk) then
         state_v := mac_smi_ready & mac_smi_rden;
         case state_v is
            when "10" => -- Start new read
               -- Store result.
               mac_smi_registers(conv_integer(mac_smi_addr)*16 + 15 downto conv_integer(mac_smi_addr)*16) <= mac_smi_data_out;
               -- Start next read.
               mac_smi_addr <= mac_smi_addr + 1;
               mac_smi_rden <= '1';

            when "11" => -- Wait for acknowledge
               null;
            when "01" => -- Read acknowledged
               mac_smi_rden <= '0';
            when "00" => -- Wait for result
               null;
            when others =>
               null;
         end case;

         if eth_rst = '1' then
            mac_smi_rden <= '0';
         end if;
      end if;
   end process proc_smi;


   ------------------------------
   -- Instantiate VGA -> ETH converter
   ------------------------------

   inst_convert : entity work.convert
      port map (
         vga_clk_i    => vga_clk,
         vga_rst_i    => vga_rst,
         vga_col_i    => vga_col,
         vga_hs_i     => vga_hs,
         vga_vs_i     => vga_vs,
         vga_hcount_i => vga_hcount,
         vga_vcount_i => vga_vcount,

         eth_clk_i    => eth_clk,
         eth_rst_i    => eth_rst,
         eth_data_o   => mac_tx_data,
         eth_sof_o    => mac_tx_sof,
         eth_eof_o    => mac_tx_eof,
         eth_empty_o  => mac_tx_empty,
         eth_rden_i   => mac_tx_rden  
      );


   ------------------------------
   -- Ethernet PHY
   ------------------------------

   inst_ethernet : entity work.ethernet
   generic map (
      G_RESET_SIZE => G_RESET_SIZE
   )
   port map (
      clk50_i      => eth_clk,
      rst_i        => eth_rst,
      -- SMI interface
      smi_ready_o  => mac_smi_ready,
      smi_phy_i    => mac_smi_phy,
      smi_addr_i   => mac_smi_addr,
      smi_rden_i   => mac_smi_rden,
      smi_data_o   => mac_smi_data_out,
      smi_wren_i   => mac_smi_wren,
      smi_data_i   => mac_smi_data_in,
      --
      tx_data_i    => mac_tx_data,
      tx_sof_i     => mac_tx_sof,
      tx_eof_i     => mac_tx_eof,
      tx_empty_i   => mac_tx_empty,
      tx_rden_o    => mac_tx_rden,
      --
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i,
      eth_mdio_io  => eth_mdio_io,
      eth_mdc_o    => eth_mdc_o,
      eth_rstn_o   => eth_rstn_o,
      eth_refclk_o => eth_refclk_o
   );


   ------------------------------
   -- Hack Computer!
   ------------------------------

   inst_dut : entity work.hack 
   generic map (
      G_NEXYS4DDR  => true,              -- True, when using the Nexys4DDR board.
      G_ROM_SIZE   => 11,                -- Number of bits in ROM address
      G_RAM_SIZE   => 11,                -- Number of bits in RAM address
      G_ROM_FILE   => "rom.txt",         -- Contains the machine code
      G_FONT_FILE  => "ProggyClean.txt"  -- Contains the character font
   )
   port map (
      vga_clk_i   => vga_clk,
      cpu_clk_i   => cpu_clk,
      cpu_rst_i   => cpu_rst,
      --
      ps2_clk_i   => ps2_clk_i,
      ps2_data_i  => ps2_data_i,
      --
      eth_debug_i => mac_smi_registers,
      led_o       => open,
      --
      vga_hs_o     => vga_hs,
      vga_vs_o     => vga_vs,
      vga_col_o    => vga_col,
      vga_hcount_o => vga_hcount,
      vga_vcount_o => vga_vcount
   );

 
   led_o(15 downto 0) <= (others => '0');

   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;
   vga_col_o <= col8to12(vga_col);
   
end Structural;

