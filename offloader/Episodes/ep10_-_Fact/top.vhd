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

   constant C_SIZE       : integer := 72;
   constant C_NUM_FACTS  : integer := 40;
   constant C_MY_MAC     : std_logic_vector(47 downto 0) := X"001122334455";
   constant C_MY_IP      : std_logic_vector(31 downto 0) := X"C0A8014D";     -- 192.168.1.77
   constant C_MY_UDP     : std_logic_vector(15 downto 0) := X"1234";         -- 4660

   -- Clock and reset
   signal vga_clk        : std_logic;
   signal vga_rst        : std_logic;
   signal eth_clk        : std_logic;
   signal eth_rst        : std_logic;
   signal math_clk       : std_logic;
   signal math_rst       : std_logic;

   -- Connected to UDP client
   signal eth_rx_valid   : std_logic;
   signal eth_rx_data    : std_logic_vector(60*8-1 downto 0);
   signal eth_rx_last    : std_logic;
   signal eth_rx_bytes   : std_logic_vector(5 downto 0);
   signal eth_tx_valid   : std_logic;
   signal eth_tx_data    : std_logic_vector(60*8-1 downto 0);
   signal eth_tx_last    : std_logic;
   signal eth_tx_bytes   : std_logic_vector(5 downto 0);

   signal math_rx_valid  : std_logic;
   signal math_rx_data   : std_logic_vector(60*8-1 downto 0);
   signal math_rx_last   : std_logic;
   signal math_rx_bytes  : std_logic_vector(5 downto 0);
   signal math_tx_valid  : std_logic;
   signal math_tx_data   : std_logic_vector(60*8-1 downto 0);
   signal math_tx_last   : std_logic;
   signal math_tx_bytes  : std_logic_vector(5 downto 0);
   signal math_debug     : std_logic_vector(255 downto 0);

   -- Test signal
   signal eth_debug      : std_logic_vector(255 downto 0);
   signal vga_hex        : std_logic_vector(255 downto 0);

begin
   
   --------------------------------------
   -- Instantiate Clock and Reset module
   --------------------------------------

   i_clk_rst : entity work.clk_rst
   port map (
      sys_clk_i  => clk_i,
      vga_clk_o  => vga_clk,
      vga_rst_o  => vga_rst,
      eth_clk_o  => eth_clk,
      eth_rst_o  => eth_rst,
      math_clk_o => math_clk,
      math_rst_o => math_rst
   ); -- i_clk_rst


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
      rst_i          => eth_rst,
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


   --------------------------------------------------
   -- Instantiate Clock Domain Crossing
   --------------------------------------------------

   i_wide_fifo_eth2math : entity work.wide_fifo
   port map (
      a_clk_i    => eth_clk,
      a_rst_i    => eth_rst,
      a_valid_i  => eth_rx_valid,
      a_data_i   => eth_rx_data,
      a_last_i   => eth_rx_last,
      a_bytes_i  => eth_rx_bytes,
      b_clk_i    => math_clk,
      b_rst_i    => math_rst,
      b_valid_o  => math_rx_valid,
      b_data_o   => math_rx_data,
      b_last_o   => math_rx_last,
      b_bytes_o  => math_rx_bytes
   ); -- i_wide_fifo_eth2math


   --------------------------------------------------
   -- Instantiate math module
   --------------------------------------------------

   i_math : entity work.math
   generic map (
      G_NUM_FACTS => C_NUM_FACTS,
      G_SIZE      => C_SIZE
   )
   port map (
      clk_i       => math_clk,
      rst_i       => math_rst,
      debug_o     => math_debug,
      rx_valid_i  => math_rx_valid,
      rx_data_i   => math_rx_data,
      rx_last_i   => math_rx_last,
      rx_bytes_i  => math_rx_bytes,
      tx_valid_o  => math_tx_valid,
      tx_data_o   => math_tx_data,
      tx_last_o   => math_tx_last,
      tx_bytes_o  => math_tx_bytes
   ); -- i_math


   --------------------------------------------------
   -- Instantiate Clock Domain Crossing
   --------------------------------------------------

   i_wide_fifo_math2eth : entity work.wide_fifo
   port map (
      a_clk_i    => math_clk,
      a_rst_i    => math_rst,
      a_valid_i  => math_tx_valid,
      a_data_i   => math_tx_data,
      a_last_i   => math_tx_last,
      a_bytes_i  => math_tx_bytes,
      b_clk_i    => eth_clk,
      b_rst_i    => eth_rst,
      b_valid_o  => eth_tx_valid,
      b_data_o   => eth_tx_data,
      b_last_o   => eth_tx_last,
      b_bytes_o  => eth_tx_bytes
   ); -- i_wide_fifo_math2eth


   --------------------------------------------------
   -- Instantiate Clock Domain Crossing
   --------------------------------------------------

   i_cdc : entity work.cdc
   generic map (
      G_WIDTH => 256
   )
   port map (
      src_clk_i  => math_clk,
      src_data_i => math_debug,
      dst_clk_i  => vga_clk,
      dst_data_o => vga_hex
   ); -- i_cdc

end architecture structural;

