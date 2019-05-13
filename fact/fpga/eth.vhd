library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the low-level interface to the LAN8720A Ethernet PHY.
-- The PHY supports the RMII specification.

entity eth is
   port (
      eth_clk_i      : in    std_logic;   -- 50 MHz
      eth_rst_i      : in    std_logic;

      -- Tx Pulling interface
      tx_data_i      : in    std_logic_vector(7 downto 0);
      tx_sof_i       : in    std_logic;
      tx_eof_i       : in    std_logic;
      tx_empty_i     : in    std_logic;
      tx_rden_o      : out   std_logic;

      -- Rx Pushing interface
      rx_data_o      : out   std_logic_vector(7 downto 0);
      rx_sof_o       : out   std_logic;
      rx_eof_o       : out   std_logic;
      rx_en_o        : out   std_logic;
      rx_err_o       : out   std_logic;
      rx_crc_valid_o : out   std_logic;

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
end eth;

architecture Structural of eth is

   signal tx_empty_ready : std_logic;

begin

   tx_empty_ready <= tx_empty_i or eth_rst_i;

   inst_eth_rx : entity work.eth_rx
      port map (
         eth_clk_i    => eth_clk_i,
         eth_rst_i    => eth_rst_i,
         data_o       => rx_data_o,
         sof_o        => rx_sof_o,
         eof_o        => rx_eof_o,
         ena_o        => rx_en_o,
         err_o        => rx_err_o,
         crc_valid_o  => rx_crc_valid_o,
         eth_rxd_i    => eth_rxd_i,
         eth_rxerr_i  => eth_rxerr_i,
         eth_crsdv_i  => eth_crsdv_i,
         eth_intn_i   => eth_intn_i
      );

   inst_eth_tx : entity work.eth_tx
      port map (
         eth_clk_i    => eth_clk_i,
         eth_rst_i    => eth_rst_i,
         data_i       => tx_data_i,
         sof_i        => tx_sof_i,
         eof_i        => tx_eof_i,
         empty_i      => tx_empty_ready,
         rden_o       => tx_rden_o,
         eth_txd_o    => eth_txd_o,
         eth_txen_o   => eth_txen_o
      );

   eth_refclk_o <= eth_clk_i;
   eth_rstn_o   <= not eth_rst_i;

end Structural;

