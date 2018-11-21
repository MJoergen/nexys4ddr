library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides a high-level interface to the Ethernet port.

entity ethernet is
   port (
      -- Connected to PHY.
      eth_clk_i    : in    std_logic; -- Must be 50 MHz
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
      -- Connected to overlay
      eth_debug_o  : out   std_logic_vector(15 downto 0)
   );
end ethernet;

architecture structural of ethernet is

   -- Minimum reset assert time for the Ethernet PHY is 25 ms.
   -- At 50 MHz (= 20 ns pr clock cycle) this is approx 2*10^6 clock cycles.
   -- Therefore, the rst_cnt has a size of 21 bits, which means that
   -- 'eth_rst' is deasserted after 40 ms.
   signal eth_rst       : std_logic := '1';
   signal eth_rst_cnt   : std_logic_vector(20 downto 0) := (others => '1');

   -- Connected to the PHY
   signal eth_rx_valid  : std_logic;
   signal eth_rx_eof    : std_logic;
   signal eth_rx_data   : std_logic_vector(7 downto 0);
   signal eth_rx_error  : std_logic_vector(1 downto 0);
   signal eth_tx_empty  : std_logic;
   signal eth_tx_rden   : std_logic;
   signal eth_tx_data   : std_logic_vector(7 downto 0);
   signal eth_tx_eof    : std_logic;

   signal eth_debug : std_logic_vector(15 downto 0);

begin

   ------------------------------
   -- Generates reset signal for the Ethernet PHY.
   ------------------------------

   proc_eth_rst : process (eth_clk_i)
   begin
      if rising_edge(eth_clk_i) then
         if eth_rst_cnt /= 0 then
            eth_rst_cnt <= eth_rst_cnt - 1;
         else
            eth_rst <= '0';
         end if;

         -- During simulation we want the reset pulse to be much shorter.
         -- pragma synthesis_off
         eth_rst_cnt(20 downto 4) <= (others => '0');
         -- pragma synthesis_on
      end if;
   end process proc_eth_rst;
   
   -- For now, just tie the transmit signals to a constant value.
   eth_tx_empty <= '1';
   eth_tx_data  <= (others => '0');
   eth_tx_eof   <= '0';


   ------------------------------
   -- Ethernet LAN 8720A PHY
   ------------------------------

   inst_phy : entity work.lan8720a
   port map (
      clk_i        => eth_clk_i,
      rst_i        => eth_rst,
      -- Rx interface
      rx_valid_o   => eth_rx_valid,
      rx_eof_o     => eth_rx_eof,
      rx_data_o    => eth_rx_data,
      rx_error_o   => eth_rx_error,
      -- Tx interface
      tx_empty_i   => eth_tx_empty,
      tx_rden_o    => eth_tx_rden,
      tx_data_i    => eth_tx_data,
      tx_eof_i     => eth_tx_eof,
      -- External pins to the LAN 8720A PHY
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

   ----------------------------------------------------------------------------
   -- Debug counter to count the number of valid frames (no receive errors and
   -- no CRC errors).
   ----------------------------------------------------------------------------
   proc_debug : process (eth_clk_i)
   begin
      if rising_edge(eth_clk_i) then
         if eth_rx_valid = '1' and eth_rx_eof = '1' and eth_rx_error = "00" then
            eth_debug <= eth_debug + 1;
         end if;
         if eth_rst = '1' then
            eth_debug <= (others => '0');
         end if;
      end if;
   end process proc_debug;

   -- Connect output signal
   eth_debug_o <= eth_debug;
   
end structural;

