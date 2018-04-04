library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module provides the low-level interface to the LAN8720A Ethernet PHY.
-- The PHY supports the RMII specification.

-- This module connects to the LAN8720A Ethernet PHY. The PHY supports the RMII specification.
--
-- From the NEXYS 4 DDR schematic
-- RXD0/MODE0   : External pull UP
-- RXD1/MODE1   : External pull UP
-- CRS_DV/MODE2 : External pull UP
-- RXERR/PHYAD0 : External pull UP
-- MDIO         : External pull UP
-- LED2/NINTSEL : According to note on schematic, the PHY operates in REF_CLK in Mode (ETH_REFCLK = 50 MHz). External pull UP.
-- LED1/REGOFF  : Floating (LOW)
-- NRST         : External pull UP
--
-- This means:
-- MODE    => All capable. Auto-negotiation enabled.
-- PHYAD   => SMI address 1
-- REGOFF  => Internal 1.2 V regulator is ENABLED.
-- NINTSEL => nINT/REFCLKO is an active low interrupt output.
--            The REF_CLK is sourced externally and must be driven
--            on the XTAL1/CLKIN pin.
--
-- All signals are connected to BANK 16 of the FPGA, except: eth_rstn_o and eth_clkin_o are connected to BANK 35.
--
-- When transmitting, packets must be preceeded by an 8-byte preamble
-- in hex: 55 55 55 55 55 55 55 D5
-- Each byte is transmitted with LSB first.
-- Frames are appended with a 32-bit CRC, and then followed by 12 bytes of interpacket gap (idle).
--
-- Timing (from the data sheet):
-- On the transmit side: The MAC controller drives the transmit data onto the
-- TXD bus and asserts TXEN to indicate valid data.  The data is latched by the
-- transceivers RMII block on the rising edge of REF_CLK. The data is in the
-- form of 2-bit wide 50MHz data. 
-- SSD (/J/K/) is "Sent for rising TXEN".
--
-- On the receive side: The 2-bit data nibbles are sent to the RMII block.
-- These data nibbles are clocked to the controller at a rate of 50MHz. The
-- controller samples the data on the rising edge of XTAL1/CLKIN (REF_CLK). To
-- ensure that the setup and hold requirements are met, the nibbles are clocked
-- out of the transceiver on the falling edge of XTAL1/CLKIN (REF_CLK). 

entity eth is
   port (
      eth_clk_i      : in    std_logic;
      eth_rst_i      : in    std_logic;

      -- SMI interface
      smi_ready_o    : out   std_logic;
      smi_phy_i      : in    std_logic_vector(4 downto 0);
      smi_addr_i     : in    std_logic_vector(4 downto 0);
      smi_rden_i     : in    std_logic;
      smi_data_o     : out   std_logic_vector(15 downto 0);
      smi_wren_i     : in    std_logic;
      smi_data_i     : in    std_logic_vector(15 downto 0);

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
   signal smi_ready      : std_logic;

begin

   tx_empty_ready <= tx_empty_i or eth_rst_i;
   smi_ready_o    <= smi_ready and not eth_rst_i;

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

   inst_eth_smi : entity work.eth_smi
      port map (
         eth_clk_i    => eth_clk_i,
         eth_rst_i    => eth_rst_i,
         ready_o      => smi_ready, 
         phy_i        => smi_phy_i,
         addr_i       => smi_addr_i,
         rden_i       => smi_rden_i,
         data_o       => smi_data_o,
         wren_i       => smi_wren_i,
         data_i       => smi_data_i,
         eth_mdio_io  => eth_mdio_io,
         eth_mdc_o    => eth_mdc_o    
      );

   eth_refclk_o <= eth_clk_i;
   eth_rstn_o   <= not eth_rst_i;

end Structural;

