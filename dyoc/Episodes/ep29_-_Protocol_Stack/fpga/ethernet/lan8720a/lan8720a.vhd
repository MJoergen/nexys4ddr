library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module interfaces to the LAN8720A Ethernet PHY, see:
-- http://ww1.microchip.com/downloads/en/DeviceDoc/8720a.pdf
-- on the NEXYS 4 DDR, see sheet 5 of the schematic here:
-- https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf

-- Notes on how the PHY is connected (strapped):
-- RXD0/MODE0   : External pull UP
-- RXD1/MODE1   : External pull UP
-- CRS_DV/MODE2 : External pull UP
-- RXERR/PHYAD0 : External pull UP
-- MDIO         : External pull UP
-- LED2/NINTSEL : According to note on schematic, the PHY operates in REF_CLK
-- In Mode (ETH_REFCLK = 50 MHz). External pull UP.
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

entity lan8720a is
   port (
      clk_i        : in    std_logic;
      rst_i        : in    std_logic;

      -- Rx interface
      rx_valid_o   : out   std_logic;
      rx_eof_o     : out   std_logic;
      rx_data_o    : out   std_logic_vector(7 downto 0);
      rx_error_o   : out   std_logic_vector(1 downto 0);

      -- Tx interface
      tx_empty_i   : in    std_logic;
      tx_rden_o    : out   std_logic;
      tx_data_i    : in    std_logic_vector(7 downto 0);
      tx_eof_i     : in    std_logic;

      -- Connected to the LAN8720A Ethernet PHY.
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic
   );
end lan8720a;

architecture structural of lan8720a is

begin

   inst_rmii_rx : entity work.rmii_rx
      port map (
         clk_i        => clk_i,
         rst_i        => rst_i,
         user_valid_o => rx_valid_o,
         user_eof_o   => rx_eof_o,
         user_data_o  => rx_data_o,
         user_error_o => rx_error_o,
         phy_rxd_i    => eth_rxd_i,
         phy_rxerr_i  => eth_rxerr_i,
         phy_crsdv_i  => eth_crsdv_i,
         phy_intn_i   => eth_intn_i
      );

   inst_rmii_tx : entity work.rmii_tx
      port map (
         clk_i        => clk_i,
         rst_i        => rst_i,
         user_empty_i => tx_empty_i,
         user_rden_o  => tx_rden_o,
         user_data_i  => tx_data_i,
         user_eof_i   => tx_eof_i,
         eth_txd_o    => eth_txd_o,
         eth_txen_o   => eth_txen_o 
      );

   eth_refclk_o <= clk_i;
   eth_rstn_o   <= not rst_i;

   eth_mdio_io <= 'Z';  -- High impedance state, i.e. disconnected.
   eth_mdc_o   <= '0';

end structural;

