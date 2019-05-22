library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the top-level instantiation of the Ethernet module.

-- This module requires a clock of 50 MHz.


entity eth is
   port (
      clk_i          : in    std_logic;           -- Must be 50 MHz.
      debug_o        : out   std_logic_vector(255 downto 0);

      -- Connected to UDP client
      udp_rx_data_o  : out   std_logic_vector(7 downto 0);
      udp_rx_sof_o   : out   std_logic;
      udp_rx_eof_o   : out   std_logic;
      udp_rx_valid_o : out   std_logic;
      udp_tx_empty_i : in    std_logic;
      udp_tx_rden_o  : out   std_logic;
      udp_tx_data_i  : in    std_logic_vector(7 downto 0);
      udp_tx_sof_i   : in    std_logic;
      udp_tx_eof_i   : in    std_logic;

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

   constant C_MY_MAC       : std_logic_vector(47 downto 0) := X"001122334455";
   constant C_MY_IP        : std_logic_vector(31 downto 0) := X"C0A8014D";     -- 192.168.1.77
   constant C_MY_PORT      : std_logic_vector(15 downto 0) := X"1234";         -- 

   signal rst              : std_logic                     := '1';
   signal rst_cnt          : std_logic_vector(20 downto 0) := (others => '1');

   -- Output from eth_rx
   signal rx_data          : std_logic_vector(7 downto 0);
   signal rx_sof           : std_logic;
   signal rx_eof           : std_logic;
   signal rx_valid         : std_logic;
   signal rx_ok            : std_logic;

   -- Output from strip_crc
   signal st_data          : std_logic_vector(7 downto 0);
   signal st_sof           : std_logic;
   signal st_eof           : std_logic;
   signal st_valid         : std_logic;

   -- Output from ARP
   signal arp_tx_data      : std_logic_vector(7 downto 0);
   signal arp_tx_sof       : std_logic;
   signal arp_tx_eof       : std_logic;
   signal arp_tx_empty     : std_logic;
   signal arp_tx_rden      : std_logic;

   -- Output from ICMP
   signal icmp_tx_data     : std_logic_vector(7 downto 0);
   signal icmp_tx_sof      : std_logic;
   signal icmp_tx_eof      : std_logic;
   signal icmp_tx_empty    : std_logic;
   signal icmp_tx_rden     : std_logic;

   -- Output from UDP
   signal udp_tx_empty     : std_logic;
   signal udp_tx_rden      : std_logic;
   signal udp_tx_data      : std_logic_vector(7 downto 0);
   signal udp_tx_sof       : std_logic;
   signal udp_tx_eof       : std_logic;

   -- Input to_eth_tx
   signal tx_data          : std_logic_vector(7 downto 0);
   signal tx_sof           : std_logic;
   signal tx_eof           : std_logic;
   signal tx_empty         : std_logic;
   signal tx_rden          : std_logic;

begin

   --------------------------------------------------
   -- Generate reset.
   -- The Ethernet PHY requires a reset pulse of at least 25 ms according to
   -- the data sheet.
   -- The reset pulse generated here will have a length of 2^21 cycles at 50
   -- MHz, i.e. 42 ms.
   --------------------------------------------------

   p_eth_rst : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_cnt /= 0 then
            rst_cnt <= rst_cnt - 1;
         else
            rst <= '0';
         end if;

-- pragma synthesis_off
-- This is added to make the reset pulse much shorter during simulation.
         rst_cnt(20 downto 4) <= (others => '0');
-- pragma synthesis_on
      end if;
   end process p_eth_rst;


   --------------------------------------------------
   -- Instantiate Rx path
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => clk_i,
      eth_rst_i   => rst,
      eth_rxd_i   => eth_rxd_i,
      eth_rxerr_i => eth_rxerr_i,
      eth_crsdv_i => eth_crsdv_i,
      --
      rx_data_o   => rx_data,
      rx_sof_o    => rx_sof,
      rx_eof_o    => rx_eof,
      rx_valid_o  => rx_valid,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_strip_crc : entity work.strip_crc
   port map (
      clk_i       => clk_i,
      rst_i       => rst,
      rx_valid_i  => rx_valid,
      rx_sof_i    => rx_sof,
      rx_eof_i    => rx_eof,
      rx_ok_i     => rx_ok,
      rx_data_i   => rx_data,
      --
      out_valid_o => st_valid,
      out_sof_o   => st_sof,
      out_eof_o   => st_eof,
      out_data_o  => st_data
   ); -- i_strip_crc


   --------------------------------------------------
   -- Instantiate ARP processing
   --------------------------------------------------

   i_arp : entity work.arp
   generic map (
      G_MY_MAC   => C_MY_MAC,
      G_MY_IP    => C_MY_IP
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst,
      rx_data_i  => st_data,
      rx_sof_i   => st_sof,
      rx_eof_i   => st_eof,
      rx_valid_i => st_valid,
      --
      tx_empty_o => arp_tx_empty,
      tx_rden_i  => arp_tx_rden,
      tx_data_o  => arp_tx_data,
      tx_sof_o   => arp_tx_sof,
      tx_eof_o   => arp_tx_eof,
      debug_o    => open
   ); -- i_arp


   --------------------------------------------------
   -- Instantiate ICMP processing
   --------------------------------------------------

   i_icmp : entity work.icmp
   generic map (
      G_MY_MAC   => C_MY_MAC,
      G_MY_IP    => C_MY_IP
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst,
      rx_data_i  => st_data,
      rx_sof_i   => st_sof,
      rx_eof_i   => st_eof,
      rx_valid_i => st_valid,
      --
      tx_empty_o => icmp_tx_empty,
      tx_rden_i  => icmp_tx_rden,
      tx_data_o  => icmp_tx_data,
      tx_sof_o   => icmp_tx_sof,
      tx_eof_o   => icmp_tx_eof,
      debug_o    => debug_o
   ); -- i_icmp

   i_udp : entity work.udp
   generic map (
      G_MY_MAC       => C_MY_MAC,
      G_MY_IP        => C_MY_IP,
      G_MY_PORT      => C_MY_PORT
   )
   port map (
      clk_i          => clk_i,
      rst_i          => rst,
      rx_phy_data_i  => st_data,
      rx_phy_sof_i   => st_sof,
      rx_phy_eof_i   => st_eof,
      rx_phy_valid_i => st_valid,
      rx_cli_data_o  => udp_rx_data_o,
      rx_cli_sof_o   => udp_rx_sof_o,
      rx_cli_eof_o   => udp_rx_eof_o,
      rx_cli_valid_o => udp_rx_valid_o,
      tx_cli_empty_i => udp_tx_empty_i,
      tx_cli_rden_o  => udp_tx_rden_o,
      tx_cli_data_i  => udp_tx_data_i,
      tx_cli_sof_i   => udp_tx_sof_i,
      tx_cli_eof_i   => udp_tx_eof_i,
      tx_phy_empty_o => udp_tx_empty,
      tx_phy_rden_i  => udp_tx_rden,
      tx_phy_data_o  => udp_tx_data,
      tx_phy_sof_o   => udp_tx_sof,
      tx_phy_eof_o   => udp_tx_eof
   ); -- i_udp


   --------------------------------------------------
   -- Lazy multiplexer.
   -- This will geenerate corrupted packets if
   -- the two blocks, ARP and ICMP, try to
   -- send at the same time.
   --------------------------------------------------

   tx_empty <= icmp_tx_empty and arp_tx_empty;
   tx_data  <= icmp_tx_data  or arp_tx_data;
   tx_sof   <= icmp_tx_sof   or arp_tx_sof;
   tx_eof   <= icmp_tx_eof   or arp_tx_eof;

   arp_tx_rden  <= tx_rden and not arp_tx_empty;
   icmp_tx_rden <= tx_rden and not icmp_tx_empty;


   --------------------------------------------------
   -- Instantiate Tx path
   --------------------------------------------------

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i  => clk_i,
      eth_rst_i  => rst,
      tx_data_i  => tx_data,
      tx_sof_i   => tx_sof,
      tx_eof_i   => tx_eof,
      tx_empty_i => tx_empty,
      tx_rden_o  => tx_rden,
      tx_err_o   => open,
      eth_txd_o  => eth_txd_o,
      eth_txen_o => eth_txen_o
   ); -- i_eth_tx


   --------------------------------------------------
   -- Connect output ports
   --------------------------------------------------

   eth_refclk_o <= clk_i;
   eth_rstn_o   <= not rst;

end Structural;

