library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the top-level instantiation of the Ethernet module.

-- This module requires a clock of 50 MHz.


entity eth is
   port (
      clk_i        : in    std_logic;           -- Must be 50 MHz.
      debug_o      : out   std_logic_vector(255 downto 0);

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;           -- Not used
      eth_mdio_io  : inout std_logic := 'Z';    -- Not used
      eth_mdc_o    : out   std_logic := '0';    -- Not used
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic
   );
end eth;

architecture Structural of eth is

   constant C_MY_MAC : std_logic_vector(47 downto 0) := X"001122334455";
   constant C_MY_IP  : std_logic_vector(31 downto 0) := X"C0A8014D";     -- 192.168.1.77

   signal rst        : std_logic                     := '1';
   signal rst_cnt    : std_logic_vector(20 downto 0) := (others => '1');

   -- Output from eth_rx
   signal rx_data    : std_logic_vector(7 downto 0);
   signal rx_sof     : std_logic;
   signal rx_eof     : std_logic;
   signal rx_valid   : std_logic;
   signal rx_ok      : std_logic;

   -- Output from strip_crc
   signal st_data    : std_logic_vector(7 downto 0);
   signal st_sof     : std_logic;
   signal st_eof     : std_logic;
   signal st_valid   : std_logic;

   -- Output from ARP
   signal tx_data    : std_logic_vector(7 downto 0);
   signal tx_sof     : std_logic;
   signal tx_eof     : std_logic;
   signal tx_empty   : std_logic;
   signal tx_rden    : std_logic;
   signal tx_err     : std_logic;

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
      tx_empty_o => tx_empty,
      tx_rden_i  => tx_rden,
      tx_data_o  => tx_data,
      tx_sof_o   => tx_sof,
      tx_eof_o   => tx_eof,
      debug_o    => debug_o
   ); -- i_arp


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
      tx_err_o   => tx_err,
      eth_txd_o  => eth_txd_o,
      eth_txen_o => eth_txen_o
   ); -- i_eth_tx


   --------------------------------------------------
   -- Connect output ports
   --------------------------------------------------

   eth_refclk_o <= clk_i;
   eth_rstn_o   <= not rst;

end Structural;

