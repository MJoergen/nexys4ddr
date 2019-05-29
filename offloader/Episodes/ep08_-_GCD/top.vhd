library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity
-- are mapped directly to pins on the FPGA.

-- In this version the design can generate a checker board
-- pattern on the VGA output.

entity top is
   port (
      clk_i        : in  std_logic;                      -- 100 MHz

      -- Connected to Ethernet port
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

      -- Connected to VGA port
      vga_hs_o     : out std_logic;
      vga_vs_o     : out std_logic;
      vga_col_o    : out std_logic_vector(11 downto 0)   -- RRRRGGGGBBB
   );
end top;

architecture structural of top is

   constant C_MY_MAC : std_logic_vector(47 downto 0) := X"001122334455";
   constant C_MY_IP  : std_logic_vector(31 downto 0) := X"C0A8014D";     -- 192.168.1.77
   constant C_MY_UDP : std_logic_vector(15 downto 0) := X"1234";         -- 4660

   -- Clock divider for VGA and ETH
   signal clk_cnt      : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk      : std_logic;
   signal eth_clk      : std_logic;

   signal eth_rst      : std_logic;

   -- Connected to UDP client
   signal eth_rx_valid : std_logic;
   signal eth_rx_data  : std_logic_vector(60*8-1 downto 0);
   signal eth_rx_last  : std_logic;
   signal eth_rx_bytes : std_logic_vector(5 downto 0);
   signal eth_tx_valid : std_logic;
   signal eth_tx_data  : std_logic_vector(60*8-1 downto 0);
   signal eth_tx_last  : std_logic;
   signal eth_tx_bytes : std_logic_vector(5 downto 0);

   -- Test signal
   signal eth_debug    : std_logic_vector(255 downto 0);
   signal vga_hex      : std_logic_vector(255 downto 0);

begin
   
   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   clk_cnt_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         clk_cnt <= clk_cnt + 1;
      end if;
   end process clk_cnt_proc;

   vga_clk <= clk_cnt(1);  -- 25 MHz
   eth_clk <= clk_cnt(0);  -- 50 MHz


   --------------------------------------------------
   -- Instantiate VGA module
   --------------------------------------------------

   i_vga : entity work.vga
   port map (
      clk_i     => vga_clk,
      hex_i     => vga_hex,
      vga_hs_o  => vga_hs_o,
      vga_vs_o  => vga_vs_o,
      vga_col_o => vga_col_o
   ); -- i_vga


   --------------------------------------------------
   -- Instantiate Ethernet module
   --------------------------------------------------

   i_eth : entity work.eth
   generic map (
      G_MY_MAC => C_MY_MAC,
      G_MY_IP  => C_MY_IP,
      G_MY_UDP => C_MY_UDP
   )
   port map (
      clk_i          => eth_clk,
      debug_o        => eth_debug,
      udp_rx_valid_o => eth_rx_valid,
      udp_rx_data_o  => eth_rx_data,
      udp_rx_last_o  => eth_rx_last,
      udp_rx_bytes_o => eth_rx_bytes,
      udp_tx_valid_i => eth_tx_valid,
      udp_tx_data_i  => eth_tx_data,
      udp_tx_last_i  => eth_tx_last,
      udp_tx_bytes_i => eth_tx_bytes,
      eth_txd_o      => eth_txd_o,
      eth_txen_o     => eth_txen_o,
      eth_rxd_i      => eth_rxd_i,
      eth_rxerr_i    => eth_rxerr_i,
      eth_crsdv_i    => eth_crsdv_i,
      eth_intn_i     => eth_intn_i,
      eth_mdio_io    => eth_mdio_io,
      eth_mdc_o      => eth_mdc_o,
      eth_rstn_o     => eth_rstn_o,
      eth_refclk_o   => eth_refclk_o
   ); -- i_eth

   eth_rst <= not eth_rstn_o;


   --------------------------------------------------
   -- Instantiate test module
   --------------------------------------------------

   i_inverter : entity work.inverter
   port map (
      clk_i      => eth_clk,
      rst_i      => eth_rst,
      rx_valid_i => eth_rx_valid,
      rx_data_i  => eth_rx_data,
      rx_last_i  => eth_rx_last,
      rx_bytes_i => eth_rx_bytes,
      tx_valid_o => eth_tx_valid,
      tx_data_o  => eth_tx_data,
      tx_last_o  => eth_tx_last,
      tx_bytes_o => eth_tx_bytes
   ); -- i_inverter


   --------------------------------------------------
   -- Instantiate Clock Domain Crossing
   --------------------------------------------------

   i_cdc : entity work.cdc
   generic map (
      G_WIDTH => 256
   )
   port map (
      src_clk_i  => eth_clk,
      src_data_i => eth_debug,
      dst_clk_i  => vga_clk,
      dst_data_o => vga_hex
   ); -- i_cdc

end architecture structural;

