library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the low-level interface to the LAN8720A Ethernet PHY.
-- The PHY supports the RMII specification.

entity main is
   port (
      eth_clk_i      : in    std_logic;   -- 50 MHz
      eth_rst_i      : in    std_logic;

      -- Connected to PHY
      eth_txd_o      : out   std_logic_vector(1 downto 0);
      eth_txen_o     : out   std_logic;
      eth_rxd_i      : in    std_logic_vector(1 downto 0);
      eth_rxerr_i    : in    std_logic;
      eth_crsdv_i    : in    std_logic;
      eth_intn_i     : in    std_logic;
      eth_mdio_io    : inout std_logic;
      eth_mdc_o      : out   std_logic;
      eth_rstn_o     : out   std_logic;
      eth_refclk_o   : out   std_logic
   );
end main;

architecture Structural of main is

   signal rx_valid_s     : std_logic;
   signal rx_sof_s       : std_logic;
   signal rx_eof_s       : std_logic;
   signal rx_data_s      : std_logic_vector(7 downto 0);
   signal rx_err_s       : std_logic;
   signal rx_crc_valid_s : std_logic;

   signal fr_valid_s     : std_logic;
   signal fr_sof_s       : std_logic;
   signal fr_eof_s       : std_logic;
   signal fr_data_s      : std_logic_vector(7 downto 0);

   signal arp_valid_s    : std_logic;
   signal arp_sof_s      : std_logic;
   signal arp_eof_s      : std_logic;
   signal arp_data_s     : std_logic_vector(7 downto 0);

   signal fifo_wren_s    : std_logic;
   signal fifo_wrdata_s  : std_logic_vector(15 downto 0);
   signal fifo_rddata_s  : std_logic_vector(15 downto 0);
   signal fifo_rden_s    : std_logic;
   signal fifo_empty_s   : std_logic;

   signal tx_valid_s     : std_logic;
   signal tx_sof_s       : std_logic;
   signal tx_eof_s       : std_logic;
   signal tx_data_s      : std_logic_vector(7 downto 0);

begin

   inst_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i    => eth_clk_i,
      eth_rst_i    => eth_rst_i,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i,
      data_o       => rx_data_s,
      sof_o        => rx_sof_s,
      eof_o        => rx_eof_s,
      valid_o      => rx_valid_s,
      err_o        => rx_err_s,
      crc_valid_o  => rx_crc_valid_s
   ); -- inst_eth_rx

   inst_strip_crc : entity work.strip_crc
   port map (
      clk_i          => eth_clk_i,
      rst_i          => eth_rst_i,
      rx_ena_i       => rx_valid_s,
      rx_sof_i       => rx_sof_s,
      rx_eof_i       => rx_eof_s,
      rx_err_i       => rx_err_s,
      rx_data_i      => rx_data_s,
      rx_crc_valid_i => rx_crc_valid_s,
      out_ena_o      => fr_valid_s,
      out_sof_o      => fr_sof_s,
      out_eof_o      => fr_eof_s,
      out_data_o     => fr_data_s
   ); -- inst_strip_crc

   inst_arp : entity work.arp
   generic map (
      G_MAC       => X"AABBCCDDEEFF",
      G_IP        => X"0A000002"
   )
   port map (
      clk_i       => eth_clk_i,
      rst_i       => eth_rst_i,
      rx_valid_i  => fr_valid_s,
      rx_sof_i    => fr_sof_s,
      rx_eof_i    => fr_eof_s,
      rx_data_i   => fr_data_s,
      tx_valid_o  => arp_valid_s,
      tx_sof_o    => arp_sof_s,
      tx_eof_o    => arp_eof_s,
      tx_data_o   => arp_data_s
   ); -- inst_arp

   fifo_wrdata_s <= "000000" & arp_sof_s & arp_eof_s & arp_data_s;

   inst_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16
   )
   port map (
      wr_clk_i    => eth_clk_i,
      wr_rst_i    => eth_rst_i,
      wr_en_i     => fifo_wren_s,
      wr_data_i   => fifo_wrdata_s,
      --
      rd_clk_i    => eth_clk_i,
      rd_rst_i    => eth_rst_i,
      rd_en_i     => fifo_rden_s,
      rd_data_o   => fifo_rddata_s,
      rd_empty_o  => fifo_empty_s,
      rd_error_o  => open           -- Read from empty fifo
   ); -- inst_ctrl_fifo

   tx_sof_s   <= fifo_rddata_s(9);
   tx_eof_s   <= fifo_rddata_s(8);
   tx_data_s  <= fifo_rddata_s(7 downto 0);

   inst_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i    => eth_clk_i,
      eth_rst_i    => eth_rst_i,
      sof_i        => tx_sof_s,
      eof_i        => tx_eof_s,
      data_i       => tx_data_s,
      empty_i      => fifo_empty_s,
      rden_o       => fifo_rden_s,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o
   );

   eth_refclk_o <= eth_clk_i;
   eth_rstn_o   <= not eth_rst_i;

end Structural;

