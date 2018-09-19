library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module provides a high-level interface to the Ethernet port.

entity ethernet is
   port (
      -- Connected to user
      user_clk_i   : in  std_logic;
      user_wren_o  : out std_logic;
      user_addr_o  : out std_logic_vector(15 downto 0);
      user_data_o  : out std_logic_vector( 7 downto 0);
      user_memio_i : in  std_logic_vector(55 downto 0);
      user_memio_o : out std_logic_vector(47 downto 0);

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
      eth_refclk_o : out   std_logic
   );
end ethernet;

architecture Structural of ethernet is

   -- Minimum reset assert time for the Ethernet PHY is 25 ms.
   -- At 50 MHz (= 20 ns pr clock cycle) this is approx 2*10^6 clock cycles.
   -- Therefore, the rst_cnt has a size of 21 bits, which means that
   -- 'eth_rst' is deasserted after 40 ms.
   signal eth_rst       : std_logic := '1';
   signal eth_rst_cnt   : std_logic_vector(7 downto 0) := (others => '1');

   signal eth_rx_valid  : std_logic;
   signal eth_rx_sof    : std_logic;
   signal eth_rx_eof    : std_logic;
   signal eth_rx_data   : std_logic_vector(7 downto 0);
   signal eth_rx_error  : std_logic_vector(1 downto 0);
   signal eth_fifo      : std_logic_vector(15 downto 0);

   signal user_fifo     : std_logic_vector(15 downto 0);
   signal user_empty    : std_logic;
   signal user_rden     : std_logic;
   signal user_rx_sof   : std_logic;
   signal user_rx_eof   : std_logic;
   signal user_rx_data  : std_logic_vector(7 downto 0);
   signal user_rx_error : std_logic_vector(1 downto 0);

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
      end if;
   end process proc_eth_rst;
   

   ------------------------------
   -- Ethernet LAN 8720A PHY
   ------------------------------

   inst_phy : entity work.lan8720a
   port map (
      clk_i          => eth_clk_i,
      rst_i          => eth_rst,
      -- Rx interface
      rx_valid_o     => eth_rx_valid,
      rx_sof_o       => eth_rx_sof,
      rx_eof_o       => eth_rx_eof,
      rx_data_o      => eth_rx_data,
      rx_error_o     => eth_rx_error,
      -- External pins to the LAN 8720A PHY
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
   );


   ------------------------------
   -- Map fifo signals
   ------------------------------

   eth_fifo(15)           <= eth_rx_sof;
   eth_fifo(14)           <= eth_rx_eof;
   eth_fifo(13 downto 12) <= eth_rx_error;
   eth_fifo(11 downto  8) <= (others => '0');
   eth_fifo( 7 downto  0) <= eth_rx_data;

   user_rx_sof   <= user_fifo(15);
   user_rx_eof   <= user_fifo(14);
   user_rx_error <= user_fifo(13 downto 12);
   user_rx_data  <= user_fifo( 7 downto  0);


   ------------------------------
   -- Instantiate fifo to cross clock domain
   ------------------------------

   inst_fifo : entity work.fifo
   generic map (
      G_WIDTH => 16
   )
   port map (
      wr_clk_i   => eth_clk_i,
      wr_rst_i   => eth_rst,
      wr_en_i    => eth_rx_valid,
      wr_data_i  => eth_fifo,
      wr_afull_o => open,  -- Ignored
      wr_error_o => open,  -- Ignored
      rd_clk_i   => user_clk_i,
      rd_rst_i   => '0',
      rd_en_i    => user_rden,
      rd_data_o  => user_fifo,
      rd_empty_o => user_empty,
      rd_error_o => open   -- Ignored
   );


   ------------------------------
   -- Instantiate DMA
   ------------------------------

   inst_dma : entity work.dma
   port map (
      clk_i      => user_clk_i,
      rd_empty_i => user_empty,
      rd_en_o    => user_rden,
      --
      rd_sof_i   => user_rx_sof,
      rd_eof_i   => user_rx_eof,
      rd_data_i  => user_rx_data,
      rd_error_i => user_rx_error,
      --
      wr_en_o    => user_wren_o,
      wr_addr_o  => user_addr_o,
      wr_data_o  => user_data_o,
      memio_i    => user_memio_i,
      memio_o    => user_memio_o
   );
   
end Structural;

