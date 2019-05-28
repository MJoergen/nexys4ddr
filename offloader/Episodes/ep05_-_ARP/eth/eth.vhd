library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the top-level instantiation of the Ethernet module.

-- This module requires a clock of 50 MHz.


entity eth is
   generic (
      G_MY_MAC : std_logic_vector(47 downto 0);    -- MAC address
      G_MY_IP  : std_logic_vector(31 downto 0)     -- IP address
   );
   port (
      clk_i        : in    std_logic;              -- Must be 50 MHz.
      debug_o      : out   std_logic_vector(255 downto 0);

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;              -- Not used
      eth_mdio_io  : inout std_logic := 'Z';       -- Not used
      eth_mdc_o    : out   std_logic := '0';       -- Not used
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic
   );
end eth;

architecture Structural of eth is

   signal rst        : std_logic                     := '1';
   signal rst_cnt    : std_logic_vector(20 downto 0) := (others => '1');

   -- Output from eth_rx
   signal rx_valid   : std_logic;
   signal rx_data    : std_logic_vector(7 downto 0);
   signal rx_last    : std_logic;
   signal rx_ok      : std_logic;

   -- Output from strip_crc
   signal st_valid   : std_logic;
   signal st_data    : std_logic_vector(7 downto 0);
   signal st_last    : std_logic;

   -- Output from byte2wide
   signal bw_valid   : std_logic;
   signal bw_data    : std_logic_vector(60*8-1 downto 0);
   signal bw_last    : std_logic;
   signal bw_bytes   : std_logic_vector(5 downto 0);

   -- Output from ARP
   signal arp_valid  : std_logic;
   signal arp_data   : std_logic_vector(60*8-1 downto 0);
   signal arp_last   : std_logic;
   signal arp_bytes  : std_logic_vector(5 downto 0);
   signal arp_debug  : std_logic_vector(255 downto 0);

   -- Output from wide2byte
   signal wb_empty   : std_logic;
   signal wb_rden    : std_logic;
   signal wb_data    : std_logic_vector(7 downto 0);
   signal wb_last    : std_logic;

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
      rx_valid_o  => rx_valid,
      rx_data_o   => rx_data,
      rx_last_o   => rx_last,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_strip_crc : entity work.strip_crc
   port map (
      clk_i       => clk_i,
      rst_i       => rst,
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
      G_BYTES    => 60
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst,
      rx_valid_i => st_valid,
      rx_data_i  => st_data,
      rx_last_i  => st_last,
      tx_valid_o => bw_valid,
      tx_data_o  => bw_data,
      tx_last_o  => bw_last,
      tx_bytes_o => bw_bytes
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
      rst_i      => rst,
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
   -- Instantiate Tx path
   --------------------------------------------------

   i_wide2byte : entity work.wide2byte
   generic map (
      G_BYTES    => 60
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst,
      rx_valid_i => arp_valid,
      rx_data_i  => arp_data,
      rx_last_i  => arp_last,
      rx_bytes_i => arp_bytes,
      tx_empty_o => wb_empty,
      tx_rden_i  => wb_rden,
      tx_data_o  => wb_data,
      tx_last_o  => wb_last
   ); -- i_wide2byte

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i  => clk_i,
      eth_rst_i  => rst,
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
   eth_rstn_o   <= not rst;
   debug_o      <= arp_debug;

end Structural;

