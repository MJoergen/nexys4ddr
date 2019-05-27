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

   signal rst      : std_logic                     := '1';
   signal rst_cnt  : std_logic_vector(20 downto 0) := (others => '1');
   signal debug    : std_logic_vector(255 downto 0);

   -- Output from eth_rx
   signal rx_valid : std_logic;
   signal rx_data  : std_logic_vector(7 downto 0);
   signal rx_last  : std_logic;
   signal rx_ok    : std_logic;

   -- Connected to eth_tx
   -- TBD: For now, we just assign default values to these signals
   signal tx_data  : std_logic_vector(7 downto 0)  := X"00";
   signal tx_last  : std_logic                     := '0';
   signal tx_empty : std_logic                     := '1';
   signal tx_rden  : std_logic;

begin

   --------------------------------------------------
   -- Generate debug signals.
   -- This counts the number of correctly received
   -- Ethernet frames.
   -- This will later be replaced.
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid = '1' and rx_last = '1' and rx_ok = '1' then
            debug <= debug + 1;
         end if;
         if rst = '1' then
            debug <= (others => '0');
         end if;         
      end if;
   end process p_debug;


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
      end if;
   end process p_eth_rst;


   --------------------------------------------------
   -- Instantiate Rx path
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i    => clk_i,
      eth_rst_i    => rst,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      rx_valid_o   => rx_valid,
      rx_data_o    => rx_data,
      rx_last_o    => rx_last,
      rx_ok_o      => rx_ok
   ); -- i_eth_rx


   --------------------------------------------------
   -- Instantiate Tx path
   --------------------------------------------------

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i    => clk_i,
      eth_rst_i    => rst,
      tx_data_i    => tx_data,
      tx_last_i    => tx_last,
      tx_empty_i   => tx_empty,
      tx_rden_o    => tx_rden,
      tx_err_o     => open,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o
   ); -- i_eth_tx


   --------------------------------------------------
   -- Connect output ports
   --------------------------------------------------

   eth_refclk_o <= clk_i;
   eth_rstn_o   <= not rst;
   debug_o      <= debug;

end Structural;

