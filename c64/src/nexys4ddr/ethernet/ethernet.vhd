library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ethernet is
   generic (
      G_RESET_SIZE : integer
   );
   port (
      clk50_i      : in    std_logic;        -- Must be 50 MHz
      rst_i        : in    std_logic;

      -- SMI interface
      smi_ready_o  : out   std_logic;
      smi_phy_i    : in    std_logic_vector(4 downto 0);
      smi_addr_i   : in    std_logic_vector(4 downto 0);
      smi_rden_i   : in    std_logic;
      smi_data_o   : out   std_logic_vector(15 downto 0);
      smi_wren_i   : in    std_logic;
      smi_data_i   : in    std_logic_vector(15 downto 0);

      -- Tx Pulling interface
      tx_data_i    : in    std_logic_vector(7 downto 0);
      tx_sof_i     : in    std_logic;
      tx_eof_i     : in    std_logic;
      tx_empty_i   : in    std_logic;
      tx_rden_o    : out   std_logic;

      -- Connected to PHY
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
end ethernet;

architecture Structural of ethernet is

   signal ready          : std_logic;
   signal tx_empty_ready : std_logic;
   signal smi_ready      : std_logic;

begin

   tx_empty_ready <= tx_empty_i or not ready;
   smi_ready_o    <= smi_ready and ready;

   inst_reset : entity work.reset
      generic map (
         G_RESET_SIZE => G_RESET_SIZE
      )
      port map (
         clk50_i    => clk50_i,
         rst_i      => rst_i,
         ready_o    => ready,
         eth_rstn_o => eth_rstn_o 
      );

   inst_mac : entity work.mac
      port map (
         clk50_i      => clk50_i,
         data_i       => tx_data_i,
         sof_i        => tx_sof_i,
         eof_i        => tx_eof_i,
         empty_i      => tx_empty_ready,
         rden_o       => tx_rden_o,
         eth_txd_o    => eth_txd_o,
         eth_txen_o   => eth_txen_o,
         eth_rxd_i    => eth_rxd_i,
         eth_rxerr_i  => eth_rxerr_i,
         eth_crsdv_i  => eth_crsdv_i,
         eth_intn_i   => eth_intn_i,
         eth_refclk_o => eth_refclk_o 
      );

   inst_smi : entity work.smi
      port map (
         clk50_i      => clk50_i,
         ready_o      => smi_ready, 
         phy_i        => smi_phy_i,
         addr_i       => smi_addr_i,
         rden_i       => smi_rden_i,
         data_o       => smi_data_o,
         wren_i       => smi_wren_i,
         data_i       => smi_data_i,
         eth_mdio_io  => eth_mdio_io,
         eth_mdc_o    => eth_mdc_o    
      );

end Structural;

