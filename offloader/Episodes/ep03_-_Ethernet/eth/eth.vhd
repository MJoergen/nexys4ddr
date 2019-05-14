library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides the low-level interface to the LAN8720A Ethernet PHY.
-- The PHY supports the RMII specification.

entity eth is
   port (
      clk_i          : in    std_logic;   -- 50 MHz
      debug_o        : out   std_logic_vector(255 downto 0);

      -- Connected to PHY
      eth_txd_o      : out   std_logic_vector(1 downto 0);
      eth_txen_o     : out   std_logic;
      eth_rxd_i      : in    std_logic_vector(1 downto 0);
      eth_rxerr_i    : in    std_logic;
      eth_crsdv_i    : in    std_logic;
      eth_intn_i     : in    std_logic;
      eth_mdio_io    : inout std_logic := 'Z';   -- Not used
      eth_mdc_o      : out   std_logic := '0';   -- Not used
      eth_rstn_o     : out   std_logic;
      eth_refclk_o   : out   std_logic
   );
end eth;

architecture Structural of eth is

   signal rst          : std_logic                     := '1';
   signal rst_cnt      : std_logic_vector(20 downto 0) := (others => '1');
   signal debug        : std_logic_vector(255 downto 0);

   -- Tx Pulling interface
   -- TBD: For now, we just assign default values to these signals
   signal tx_data      : std_logic_vector(7 downto 0)  := X"00";
   signal tx_sof       : std_logic                     := '0';
   signal tx_eof       : std_logic                     := '0';
   signal tx_empty     : std_logic                     := '1';
   signal tx_rden      : std_logic;

   -- Rx Pushing interface
   signal rx_data      : std_logic_vector(7 downto 0);
   signal rx_sof       : std_logic;
   signal rx_eof       : std_logic;
   signal rx_valid     : std_logic;
   signal rx_err       : std_logic;
   signal rx_crc_valid : std_logic;

begin

   --------------------------------------------------
   -- Generate debug signals
   --------------------------------------------------

   p_debug : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rx_valid = '1' and rx_eof = '1' and rx_err = '0' and rx_crc_valid = '1' then
            debug <= debug + 1;
         end if;
         if rst = '1' then
            debug <= (others => '0');
         end if;         
      end if;
   end process p_debug;


   --------------------------------------------------
   -- Generate reset.
   -- The reset pulse will have a length of 2^21 cycles
   -- at 50 MHz, i.e. 42 ms.
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
      data_o       => rx_data,
      sof_o        => rx_sof,
      eof_o        => rx_eof,
      valid_o      => rx_valid,
      err_o        => rx_err,
      crc_valid_o  => rx_crc_valid,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i
   ); -- i_eth_rx


   --------------------------------------------------
   -- Instantiate Tx path
   --------------------------------------------------

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i    => clk_i,
      eth_rst_i    => rst,
      data_i       => tx_data,
      sof_i        => tx_sof,
      eof_i        => tx_eof,
      empty_i      => tx_empty,
      rden_o       => tx_rden,
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

