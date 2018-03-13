library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

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

entity rx_mac is

   port (
      clk50_i     : in  std_logic;        -- Must be 50 MHz

      -- Pushing interface
      data_o      : out std_logic_vector(7 downto 0);
      sof_o       : out std_logic;
      eof_o       : out std_logic;
      en_o        : out std_logic;

      -- Connectedto PHY
      eth_rxd_i   : in  std_logic_vector(1 downto 0);
      eth_rxerr_i : in  std_logic;
      eth_crsdv_i : in  std_logic;
      eth_intn_i  : in  std_logic
   );
end rx_mac;

architecture Structural of rx_mac is


begin


end Structural;

