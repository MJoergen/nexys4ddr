library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module provides a high-level interface to the Ethernet port.
-- On the transmit side, it compresses and encapsulates the VGA frame data.
-- on the receive side, it writes data to the memory.

entity ethernet is
   port (
      eth_clk_i           : in  std_logic;
      eth_rst_i           : in  std_logic;

      -- Connected to PHY
      eth_txd_o           : out   std_logic_vector(1 downto 0);
      eth_txen_o          : out   std_logic;
      eth_rxd_i           : in    std_logic_vector(1 downto 0);
      eth_rxerr_i         : in    std_logic;
      eth_crsdv_i         : in    std_logic;
      eth_intn_i          : in    std_logic;
      eth_mdio_io         : inout std_logic;
      eth_mdc_o           : out   std_logic;
      eth_rstn_o          : out   std_logic;
      eth_refclk_o        : out   std_logic;

      -- Input from VGA
      vga_clk_i           : in    std_logic;
      vga_rst_i           : in    std_logic;
      vga_col_i           : in    std_logic_vector(7 downto 0);
      vga_hs_i            : in    std_logic;
      vga_vs_i            : in    std_logic;
      vga_hcount_i        : in    std_logic_vector(10 downto 0);
      vga_vcount_i        : in    std_logic_vector(10 downto 0);

      -- Output to CPU
      cpu_clk_i           : in    std_logic;
      cpu_rst_i           : in    std_logic;
      cpu_wr_addr_o       : out   std_logic_vector(15 downto 0);
      cpu_wr_en_o         : out   std_logic;
      cpu_wr_data_o       : out   std_logic_vector(7 downto 0);

      -- Debug output
      eth_smi_registers_o : out   std_logic_vector(32*16-1 downto 0);
      eth_stat_debug_o    : out   std_logic_vector(4*16-1 downto 0)
   );
end ethernet;

architecture Structural of ethernet is

   -- Ethernet PHY signals
   signal eth_smi_ready     : std_logic;
   constant eth_smi_phy     : std_logic_vector(4 downto 0) := "00001";
   signal eth_smi_addr      : std_logic_vector(4 downto 0);
   signal eth_smi_rden      : std_logic;
   signal eth_smi_data_out  : std_logic_vector(15 downto 0);
   --
   signal eth_tx_data       : std_logic_vector(7 downto 0);
   signal eth_tx_sof        : std_logic;
   signal eth_tx_eof        : std_logic;
   signal eth_tx_empty      : std_logic;
   signal eth_tx_rden       : std_logic;
   --
   signal eth_rx_data       : std_logic_vector(7 downto 0);
   signal eth_rx_sof        : std_logic;
   signal eth_rx_eof        : std_logic;
   signal eth_rx_en         : std_logic;
   signal eth_rx_err        : std_logic;
   signal eth_rx_crc_valid  : std_logic;

   signal cpu_drop          : std_logic;

   signal stats_inc         : std_logic_vector( 3 downto 0);
   signal stats_addr        : std_logic_vector( 7 downto 0);
   signal stats_data        : std_logic_vector(15 downto 0);

begin

   stats_addr <= (others => '0');

   ------------------------------
   -- Instantiate statistics
   ------------------------------

   inst_stat : entity work.stat
   generic map (
      G_NUM => 4
   )
   port map (
      clk_i   => eth_clk_i,
      rst_i   => eth_rst_i,
      inc_i   => stats_inc,
      addr_i  => stats_addr,
      data_o  => stats_data,
      debug_o => eth_stat_debug_o
   );

   ------------------------------
   -- Ethernet PHY
   ------------------------------

   inst_eth : entity work.eth
   port map (
      eth_clk_i      => eth_clk_i,
      eth_rst_i      => eth_rst_i,
      -- SMI interface
      smi_ready_o    => eth_smi_ready,
      smi_phy_i      => eth_smi_phy,
      smi_addr_i     => eth_smi_addr,
      smi_rden_i     => eth_smi_rden,
      smi_data_o     => eth_smi_data_out,
      smi_wren_i     => '0',
      smi_data_i     => (others => '0'),
      --
      tx_data_i      => eth_tx_data,
      tx_sof_i       => eth_tx_sof,
      tx_eof_i       => eth_tx_eof,
      tx_empty_i     => eth_tx_empty,
      tx_rden_o      => eth_tx_rden,
      --
      rx_data_o      => eth_rx_data,
      rx_sof_o       => eth_rx_sof,
      rx_eof_o       => eth_rx_eof,
      rx_en_o        => eth_rx_en,
      rx_err_o       => eth_rx_err,
      rx_crc_valid_o => eth_rx_crc_valid,
      --
      eth_txd_o      => eth_txd_o,
      eth_txen_o     => eth_txen_o,
      eth_rxd_i      => eth_rxd_i,
      eth_rxerr_i    => eth_rxerr_i,
      eth_crsdv_i    => eth_crsdv_i,
      eth_intn_i     => eth_intn_i,
      eth_mdio_io    => eth_mdio_io,
      eth_mdc_o      => eth_mdc_o,
      eth_rstn_o     => eth_rstn_o,
      eth_refclk_o   => eth_refclk_o
   );


   ------------------------------
   -- Read SMI from PHY
   ------------------------------

   inst_read_smi : entity work.read_smi
   port map (
      clk_i       => eth_clk_i,
      rst_i       => eth_rst_i,
      ready_i     => eth_smi_ready,
      addr_o      => eth_smi_addr,
      rden_o      => eth_smi_rden,
      data_i      => eth_smi_data_out,
      registers_o => eth_smi_registers_o
   );


   -----------------------------------
   -- Ethernet transmit
   -----------------------------------

   inst_convert : entity work.convert
      port map (
         vga_clk_i    => vga_clk_i,
         vga_rst_i    => vga_rst_i,
         vga_col_i    => vga_col_i,
         vga_hs_i     => vga_hs_i,
         vga_vs_i     => vga_vs_i,
         vga_hcount_i => vga_hcount_i,
         vga_vcount_i => vga_vcount_i,

         eth_clk_i    => eth_clk_i,
         eth_rst_i    => eth_rst_i,
         eth_data_o   => eth_tx_data,
         eth_sof_o    => eth_tx_sof,
         eth_eof_o    => eth_tx_eof,
         eth_empty_o  => eth_tx_empty,
         eth_rden_i   => eth_tx_rden
      );


   -----------------------------------
   -- Ethernet receive
   -----------------------------------
   
   inst_receive : entity work.receive
   port map (
      eth_clk_i       => eth_clk_i,
      eth_rst_i       => eth_rst_i,
      eth_ena_i       => eth_rx_en,
      eth_sof_i       => eth_rx_sof,
      eth_eof_i       => eth_rx_eof,
      eth_err_i       => eth_rx_err,
      eth_data_i      => eth_rx_data,
      eth_crc_valid_i => eth_rx_crc_valid,
      pl_clk_i        => cpu_clk_i,  
      pl_rst_i        => cpu_rst_i, 
      pl_wr_addr_o    => cpu_wr_addr_o,
      pl_wr_en_o      => cpu_wr_en_o,
      pl_wr_data_o    => cpu_wr_data_o,
      pl_drop_o       => cpu_drop
   );

   -- Layer 1 framing errors
   stats_inc(0) <= eth_rx_en and eth_rx_err;
   
   -- Layer 1 CRC errors
   stats_inc(1) <= eth_rx_en and eth_rx_eof and (not eth_rx_crc_valid);

   -- Layer 1 successfull packets
   stats_inc(2) <= eth_rx_en and eth_rx_eof and eth_rx_crc_valid;

end Structural;

