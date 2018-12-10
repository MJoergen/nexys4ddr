library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module provides a high-level interface to the Ethernet port.

entity ethernet is
   port (
      main_clk_i            : in  std_logic;
      main_rst_i            : in  std_logic;

      -- Connected to RAM
      main_txdma_ram_rd_en_o   : out std_logic;
      main_txdma_ram_rd_addr_o : out std_logic_vector(15 downto 0);
      main_txdma_ram_rd_data_i : in  std_logic_vector( 7 downto 0);
      main_rxdma_ram_wr_en_o   : out std_logic;
      main_rxdma_ram_wr_addr_o : out std_logic_vector(15 downto 0);
      main_rxdma_ram_wr_data_o : out std_logic_vector( 7 downto 0);

      -- Connected to memio
      main_txdma_ptr_i      : in  std_logic_vector(15 downto 0);
      main_txdma_enable_i   : in  std_logic;
      main_txdma_clear_o    : out std_logic;
      main_rxdma_ptr_i      : in  std_logic_vector(15 downto 0);
      main_rxdma_enable_i   : in  std_logic;
      main_rxdma_clear_o    : out std_logic;
      main_rxdma_pending_o  : out std_logic_vector( 7 downto 0);
      --
      eth_rxcnt_good_o     : out std_logic_vector(15 downto 0);
      eth_rxcnt_error_o    : out std_logic_vector( 7 downto 0);
      eth_rxcnt_crc_bad_o  : out std_logic_vector( 7 downto 0);
      eth_rxcnt_overflow_o : out std_logic_vector( 7 downto 0);
      eth_txcnt_o          : out std_logic_vector(15 downto 0);

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

architecture structural of ethernet is

   -- Minimum reset assert time for the Ethernet PHY is 25 ms.
   -- At 50 MHz (= 20 ns pr clock cycle) this is approx 2*10^6 clock cycles.
   -- Therefore, the rst_cnt has a size of 21 bits, which means that
   -- 'eth_rst' is deasserted after 40 ms.
   signal eth_rst       : std_logic := '1';
   signal eth_rst_cnt   : std_logic_vector(20 downto 0) := (others => '1');

   -- Connected to the PHY
   signal eth_rx_valid  : std_logic;
   signal eth_rx_eof    : std_logic;
   signal eth_rx_data   : std_logic_vector(7 downto 0);
   signal eth_rx_error  : std_logic_vector(1 downto 0);
   signal eth_tx_empty  : std_logic;
   signal eth_tx_rden   : std_logic;
   signal eth_tx_data   : std_logic_vector(7 downto 0);
   signal eth_tx_eof    : std_logic_vector(0 downto 0);

   -- Connection from rx_header to rxfifo
   signal eth_rxheader_valid : std_logic;
   signal eth_rxheader_data  : std_logic_vector(7 downto 0);
   signal eth_rxheader_eof   : std_logic_vector(0 downto 0);
   signal eth_rxfifo_afull   : std_logic;

   -- Connection from rxfifo to rx_dma
   signal main_rxfifo_empty : std_logic;
   signal main_rxfifo_data  : std_logic_vector(7 downto 0);
   signal main_rxfifo_eof   : std_logic_vector(0 downto 0);
   signal main_rxdma_rden   : std_logic;

   -- Connection from tx_dma to txfifo
   signal main_tx_afull : std_logic;
   signal main_tx_valid : std_logic;
   signal main_tx_data  : std_logic_vector(7 downto 0);
   signal main_tx_eof   : std_logic_vector(0 downto 0);
   
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

         -- During simulation we want the reset pulse to be much shorter.
         -- pragma synthesis_off
         eth_rst_cnt(20 downto 4) <= (others => '0');
         -- pragma synthesis_on
      end if;
   end process proc_eth_rst;
   

   ------------------------------
   -- Ethernet LAN 8720A PHY
   ------------------------------

   inst_phy : entity work.lan8720a
   port map (
      clk_i        => eth_clk_i,
      rst_i        => eth_rst,
      -- Rx interface
      rx_valid_o   => eth_rx_valid,
      rx_eof_o     => eth_rx_eof,
      rx_data_o    => eth_rx_data,
      rx_error_o   => eth_rx_error,
      -- Tx interface
      tx_empty_i   => eth_tx_empty,
      tx_rden_o    => eth_tx_rden,
      tx_data_i    => eth_tx_data,
      tx_eof_i     => eth_tx_eof(0),
      -- External pins to the LAN 8720A PHY
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o,
      eth_rxd_i    => eth_rxd_i,
      eth_rxerr_i  => eth_rxerr_i,
      eth_crsdv_i  => eth_crsdv_i,
      eth_intn_i   => eth_intn_i,
      eth_mdio_io  => eth_mdio_io,
      eth_mdc_o    => eth_mdc_o,
      eth_rstn_o   => eth_rstn_o,
      eth_refclk_o => eth_refclk_o
   );


   -------------------------------
   -- Header insertion
   -------------------------------
   inst_rx_header : entity work.rx_header
   port map (
      clk_i          => eth_clk_i,
      rst_i          => eth_rst,
      rx_valid_i     => eth_rx_valid,
      rx_eof_i       => eth_rx_eof,
      rx_data_i      => eth_rx_data,
      rx_error_i     => eth_rx_error,
      --
      cnt_good_o     => eth_rxcnt_good_o,
      cnt_error_o    => eth_rxcnt_error_o,
      cnt_crc_bad_o  => eth_rxcnt_crc_bad_o,
      cnt_overflow_o => eth_rxcnt_overflow_o,
      --
      out_afull_i    => eth_rxfifo_afull,
      out_valid_o    => eth_rxheader_valid,
      out_data_o     => eth_rxheader_data,
      out_eof_o      => eth_rxheader_eof(0)
   );


   ------------------------------
   -- Instantiate rxfifo to cross clock domain
   ------------------------------

   inst_rxfifo : entity work.fifo
   generic map (
      G_WIDTH => 8
   )
   port map (
      wr_clk_i   => eth_clk_i,
      wr_rst_i   => eth_rst,
      wr_en_i    => eth_rxheader_valid,
      wr_data_i  => eth_rxheader_data,
      wr_sb_i    => eth_rxheader_eof,
      wr_afull_o => eth_rxfifo_afull,
      wr_error_o => open,  -- Ignored
      --
      rd_clk_i   => main_clk_i,
      rd_rst_i   => '0',
      rd_en_i    => main_rxdma_rden,
      rd_data_o  => main_rxfifo_data,
      rd_sb_o    => main_rxfifo_eof,
      rd_empty_o => main_rxfifo_empty,
      rd_error_o => open   -- Ignored
   );


   ------------------------------
   -- Instantiate Rx DMA
   ------------------------------

   inst_rx_dma : entity work.rx_dma
   port map (
      clk_i        => main_clk_i,
      rst_i        => main_rst_i,
      rd_empty_i   => main_rxfifo_empty,
      rd_en_o      => main_rxdma_rden,
      rd_data_i    => main_rxfifo_data,
      rd_eof_i     => main_rxfifo_eof(0),
      --
      wr_en_o      => main_rxdma_ram_wr_en_o,
      wr_addr_o    => main_rxdma_ram_wr_addr_o,
      wr_data_o    => main_rxdma_ram_wr_data_o,
      --
      dma_ptr_i    => main_rxdma_ptr_i,
      dma_enable_i => main_rxdma_enable_i,
      dma_clear_o  => main_rxdma_clear_o
   );

   main_rxdma_pending_o <= (7 downto 1 => '0', 0 => not main_rxfifo_empty);

   ------------------------------
   -- Instantiate Tx DMA
   ------------------------------

   inst_tx_dma : entity work.tx_dma
   port map (
      clk_i          => main_clk_i,
      rst_i          => main_rst_i,
      memio_ptr_i    => main_txdma_ptr_i,
      memio_enable_i => main_txdma_enable_i,
      memio_clear_o  => main_txdma_clear_o,
      --
      rd_en_o        => main_txdma_ram_rd_en_o,
      rd_addr_o      => main_txdma_ram_rd_addr_o,
      rd_data_i      => main_txdma_ram_rd_data_i,
      --
      wr_afull_i     => main_tx_afull,
      wr_valid_o     => main_tx_valid,
      wr_data_o      => main_tx_data,
      wr_eof_o       => main_tx_eof(0),

      cnt_end_o      => eth_txcnt_o  -- TBD
   );


   ------------------------------
   -- Instantiate txfifo to cross clock domain
   ------------------------------

   inst_tx_fifo : entity work.fifo
   generic map (
      G_WIDTH => 8
   )
   port map (
      wr_clk_i   => main_clk_i,
      wr_rst_i   => '0',
      wr_en_i    => main_tx_valid,
      wr_data_i  => main_tx_data,
      wr_sb_i    => main_tx_eof,
      wr_afull_o => main_tx_afull,
      wr_error_o => open,  -- Ignored
      rd_clk_i   => eth_clk_i,
      rd_rst_i   => eth_rst,
      rd_en_i    => eth_tx_rden,
      rd_data_o  => eth_tx_data,
      rd_sb_o    => eth_tx_eof,
      rd_empty_o => eth_tx_empty,
      rd_error_o => open   -- Ignored
   );
   
end structural;

