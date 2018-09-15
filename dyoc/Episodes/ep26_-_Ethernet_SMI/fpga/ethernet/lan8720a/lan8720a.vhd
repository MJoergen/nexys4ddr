library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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

      -- SMI interface
      smi_ready_o  : out   std_logic;
      smi_rden_i   : in    std_logic;
      smi_phy_i    : in    std_logic_vector(4 downto 0);
      smi_addr_i   : in    std_logic_vector(4 downto 0);
      smi_data_o   : out   std_logic_vector(15 downto 0);
      smi_wren_i   : in    std_logic;
      smi_data_i   : in    std_logic_vector(15 downto 0);

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

architecture Structural of lan8720a is

   signal smi_ready      : std_logic;

begin

   smi_ready_o <= smi_ready and not rst_i;

   inst_smi : entity work.smi
      port map (
         clk_i        => clk_i,
         rst_i        => rst_i,
         user_ready_o => smi_ready, 
         user_phy_i   => smi_phy_i,
         user_addr_i  => smi_addr_i,
         user_rden_i  => smi_rden_i,
         user_data_o  => smi_data_o,
         user_wren_i  => smi_wren_i,
         user_data_i  => smi_data_i,
         phy_mdio_io  => eth_mdio_io,
         phy_mdc_o    => eth_mdc_o    
      );

   eth_refclk_o <= clk_i;
   eth_rstn_o   <= not rst_i;

end Structural;

