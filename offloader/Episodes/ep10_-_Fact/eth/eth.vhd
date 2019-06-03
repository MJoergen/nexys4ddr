library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the top-level instantiation of the Ethernet module.

-- This module requires a clock of 50 MHz.


entity eth is
   generic (
      G_MY_MAC : std_logic_vector(47 downto 0);    -- MAC address
      G_MY_IP  : std_logic_vector(31 downto 0);    -- IP address
      G_MY_UDP : std_logic_vector(15 downto 0)     -- UDP port
   );
   port (
      clk_i          : in    std_logic;           -- Must be 50 MHz.
      rst_i          : in    std_logic;           -- Must be at least 25 ms.
      debug_o        : out   std_logic_vector(255 downto 0);

      -- Connected to UDP client
      udp_rx_valid_o : out   std_logic;
      udp_rx_data_o  : out   std_logic_vector(60*8-1 downto 0);
      udp_rx_last_o  : out   std_logic;
      udp_rx_bytes_o : out   std_logic_vector(5 downto 0);
      udp_tx_valid_i : in    std_logic;
      udp_tx_data_i  : in    std_logic_vector(60*8-1 downto 0);
      udp_tx_last_i  : in    std_logic;
      udp_tx_bytes_i : in    std_logic_vector(5 downto 0);

      -- Connected to PHY
      eth_txd_o      : out   std_logic_vector(1 downto 0);
      eth_txen_o     : out   std_logic;
      eth_rxd_i      : in    std_logic_vector(1 downto 0);
      eth_rxerr_i    : in    std_logic;
      eth_crsdv_i    : in    std_logic;
      eth_intn_i     : in    std_logic;           -- Not used
      eth_mdio_io    : inout std_logic := 'Z';    -- Not used
      eth_mdc_o      : out   std_logic := '0';    -- Not used
      eth_rstn_o     : out   std_logic;
      eth_refclk_o   : out   std_logic
   );
end eth;

architecture Structural of eth is

   -- Output from eth_rx
   signal rx_valid    : std_logic;
   signal rx_data     : std_logic_vector(7 downto 0);
   signal rx_last     : std_logic;
   signal rx_ok       : std_logic;

   -- Output from strip_crc
   signal st_valid    : std_logic;
   signal st_data     : std_logic_vector(7 downto 0);
   signal st_last     : std_logic;

   -- Output from byte2wide
   signal bw_valid    : std_logic;
   signal bw_data     : std_logic_vector(60*8-1 downto 0);
   signal bw_last     : std_logic;
   signal bw_bytes    : std_logic_vector(5 downto 0);

   -- Output from ARP
   signal arp_valid   : std_logic;
   signal arp_data    : std_logic_vector(60*8-1 downto 0);
   signal arp_last    : std_logic;
   signal arp_bytes   : std_logic_vector(5 downto 0);
   signal arp_debug   : std_logic_vector(255 downto 0);

   -- Output from ICMP
   signal icmp_valid  : std_logic;
   signal icmp_data   : std_logic_vector(60*8-1 downto 0);
   signal icmp_last   : std_logic;
   signal icmp_bytes  : std_logic_vector(5 downto 0);
   signal icmp_debug  : std_logic_vector(255 downto 0);

   -- Output from UDP
   signal udp_valid   : std_logic;
   signal udp_data    : std_logic_vector(60*8-1 downto 0);
   signal udp_last    : std_logic;
   signal udp_bytes   : std_logic_vector(5 downto 0);
   signal udp_debug   : std_logic_vector(255 downto 0);

   -- Output from lazy multiplexer
   signal arb_valid   : std_logic;
   signal arb_data    : std_logic_vector(60*8-1 downto 0);
   signal arb_last    : std_logic;
   signal arb_bytes   : std_logic_vector(5 downto 0);

   -- Output from wide2byte
   signal wb_empty    : std_logic;
   signal wb_rden     : std_logic;
   signal wb_data     : std_logic_vector(7 downto 0);
   signal wb_last     : std_logic;

begin

   --------------------------------------------------
   -- Instantiate Rx path
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => clk_i,
      eth_rst_i   => rst_i,
      eth_rxd_i   => eth_rxd_i,
      eth_rxerr_i => eth_rxerr_i,
      eth_crsdv_i => eth_crsdv_i,
      rx_valid_o  => rx_valid,
      rx_data_o   => rx_data,
      rx_last_o   => rx_last,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_strip_crc : entity work.strip_crc
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      rx_valid_i  => rx_valid,
      rx_data_i   => rx_data,
      rx_last_i   => rx_last,
      rx_ok_i     => rx_ok,
      out_valid_o => st_valid,
      out_data_o  => st_data,
      out_last_o  => st_last
   ); -- i_strip_crc

   i_byte2wide : entity work.byte2wide
   generic map (
      G_BYTES     => 60
   )
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      rx_valid_i  => st_valid,
      rx_data_i   => st_data,
      rx_last_i   => st_last,
      tx_valid_o  => bw_valid,
      tx_data_o   => bw_data,
      tx_last_o   => bw_last,
      tx_bytes_o  => bw_bytes
   ); -- i_byte2wide


   --------------------------------------------------
   -- Instantiate ARP processing
   --------------------------------------------------

   i_arp : entity work.arp
   generic map (
      G_MY_MAC   => G_MY_MAC,
      G_MY_IP    => G_MY_IP
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      rx_valid_i => bw_valid,
      rx_data_i  => bw_data,
      rx_last_i  => bw_last,
      rx_bytes_i => bw_bytes,
      --
      tx_valid_o => arp_valid,
      tx_data_o  => arp_data,
      tx_last_o  => arp_last,
      tx_bytes_o => arp_bytes,
      debug_o    => arp_debug
   ); -- i_arp


   --------------------------------------------------
   -- Instantiate ICMP processing
   --------------------------------------------------

   i_icmp : entity work.icmp
   generic map (
      G_MY_MAC   => G_MY_MAC,
      G_MY_IP    => G_MY_IP
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      rx_valid_i => bw_valid,
      rx_data_i  => bw_data,
      rx_last_i  => bw_last,
      rx_bytes_i => bw_bytes,
      --
      tx_valid_o => icmp_valid,
      tx_data_o  => icmp_data,
      tx_last_o  => icmp_last,
      tx_bytes_o => icmp_bytes,
      debug_o    => icmp_debug
   ); -- i_icmp


   --------------------------------------------------
   -- Instantiate UDP processing
   --------------------------------------------------

   i_udp : entity work.udp
   generic map (
      G_MY_MAC       => G_MY_MAC,
      G_MY_IP        => G_MY_IP,
      G_MY_UDP       => G_MY_UDP
   )
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      rx_phy_valid_i => bw_valid,
      rx_phy_data_i  => bw_data,
      rx_phy_last_i  => bw_last,
      rx_phy_bytes_i => bw_bytes,
      tx_phy_valid_o => udp_valid,
      tx_phy_data_o  => udp_data,
      tx_phy_last_o  => udp_last,
      tx_phy_bytes_o => udp_bytes,
      debug_o        => udp_debug,
      --
      rx_cli_valid_o => udp_rx_valid_o,
      rx_cli_data_o  => udp_rx_data_o,
      rx_cli_last_o  => udp_rx_last_o,
      rx_cli_bytes_o => udp_rx_bytes_o,
      tx_cli_valid_i => udp_tx_valid_i,
      tx_cli_data_i  => udp_tx_data_i,
      tx_cli_last_i  => udp_tx_last_i,
      tx_cli_bytes_i => udp_tx_bytes_i
   ); -- i_udp


   --------------------------------------------------
   -- Lazy multiplexer.
   -- This will geenerate corrupted packets if
   -- the three blocks, ARP, ICMP, or UDP, try to
   -- send at the same time.
   --------------------------------------------------

   arb_valid <= icmp_valid or arp_valid or udp_valid;
   arb_data  <= icmp_data  or arp_data  or udp_data;
   arb_last  <= icmp_last  or arp_last  or udp_last;
   arb_bytes <= icmp_bytes or arp_bytes or udp_bytes;


   --------------------------------------------------
   -- Instantiate Tx path
   --------------------------------------------------

   i_wide2byte : entity work.wide2byte
   generic map (
      G_BYTES     => 60
   )
   port map (
      clk_i       => clk_i,
      rst_i       => rst_i,
      rx_valid_i  => arb_valid,
      rx_data_i   => arb_data,
      rx_last_i   => arb_last,
      rx_bytes_i  => arb_bytes,
      --
      tx_empty_o  => wb_empty,
      tx_rden_i   => wb_rden,
      tx_data_o   => wb_data,
      tx_last_o   => wb_last
   ); -- i_wide2byte

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i  => clk_i,
      eth_rst_i  => rst_i,
      tx_data_i  => wb_data,
      tx_last_i  => wb_last,
      tx_empty_i => wb_empty,
      tx_rden_o  => wb_rden,
      tx_err_o   => open,
      eth_txd_o  => eth_txd_o,
      eth_txen_o => eth_txen_o
   ); -- i_eth_tx


   --------------------------------------------------
   -- Connect output ports
   --------------------------------------------------

   eth_refclk_o <= clk_i;
   eth_rstn_o   <= not rst_i;
   debug_o      <= udp_debug;

end Structural;

