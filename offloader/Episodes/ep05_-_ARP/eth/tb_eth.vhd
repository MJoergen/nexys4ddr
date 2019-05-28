library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

entity tb_eth is
end tb_eth;

architecture simulation of tb_eth is

   constant C_DUT_MAC : std_logic_vector(47 downto 0) := X"001122334455";
   constant C_DUT_IP  : std_logic_vector(31 downto 0) := X"C0A8014D";     -- 192.168.1.77

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk       : std_logic;
   signal rst       : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx    : t_sim;

   -- Output from wide2byte
   signal tx_empty  : std_logic;
   signal tx_rden   : std_logic;
   signal tx_data   : std_logic_vector(7 downto 0);
   signal tx_last   : std_logic;

   -- Signals conected to DUT
   signal eth_rstn  : std_logic;
   signal eth_rxd   : std_logic_vector(1 downto 0);
   signal eth_crsdv : std_logic;
   signal eth_txd   : std_logic_vector(1 downto 0);
   signal eth_txen  : std_logic;
   signal debug     : std_logic_vector(255 downto 0);

   -- Output from eth_rx
   signal rx_valid  : std_logic;
   signal rx_last   : std_logic;
   signal rx_data   : std_logic_vector(7 downto 0);
   signal rx_ok     : std_logic;

   -- Output from strip_crc
   signal st_valid  : std_logic;
   signal st_data   : std_logic_vector(7 downto 0);
   signal st_last   : std_logic;

   -- Signals for reception of the Ethernet frames.
   signal sim_rx    : t_sim;
   signal exp       : t_sim;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

begin

   --------------------------------------------------
   -- Generate clock and reset
   --------------------------------------------------

   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns; -- 50 MHz
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;


   --------------------------------------------------
   -- Instantiate traffic generator
   --------------------------------------------------

   i_wide2byte : entity work.wide2byte
   generic map (
      G_BYTES    => 60
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => sim_tx.valid,
      rx_data_i  => sim_tx.data,
      rx_last_i  => sim_tx.last,
      rx_bytes_i => sim_tx.bytes,
      --
      tx_empty_o => tx_empty,
      tx_data_o  => tx_data,
      tx_last_o  => tx_last,
      tx_rden_i  => tx_rden
   ); -- i_wide2byte

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i  => clk,
      eth_rst_i  => rst,
      tx_data_i  => tx_data,
      tx_last_i  => tx_last,
      tx_empty_i => tx_empty,
      tx_rden_o  => tx_rden,
      tx_err_o   => open,
      --
      eth_txd_o  => eth_rxd,
      eth_txen_o => eth_crsdv
   ); -- i_eth_tx


   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------

   i_eth : entity work.eth
   generic map (
      G_MY_MAC => C_DUT_MAC,
      G_MY_IP  => C_DUT_IP
   )
   port map (
      clk_i        => clk,
      debug_o      => debug,
      eth_txd_o    => eth_txd,
      eth_txen_o   => eth_txen,
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => '0',
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => open
   ); -- i_eth


   --------------------------------------------------
   -- Instantiate traffic receiver
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => clk,
      eth_rst_i   => rst,
      eth_rxd_i   => eth_txd,
      eth_rxerr_i => '0',
      eth_crsdv_i => eth_txen,
      rx_valid_o  => rx_valid,
      rx_data_o   => rx_data,
      rx_last_o   => rx_last,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_strip_crc : entity work.strip_crc
   port map (
      clk_i       => clk,
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
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => st_valid,
      rx_data_i  => st_data,
      rx_last_i  => st_last,
      tx_valid_o => sim_rx.valid,
      tx_data_o  => sim_rx.data,
      tx_last_o  => sim_rx.last,
      tx_bytes_o => sim_rx.bytes
   ); -- i_byte2wide


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify ARP processing
      procedure verify_arp(signal tx : inout t_sim;
                           signal rx : in    t_sim) is
      begin

         report "Verify ARP processing.";

         -- Send one ARP request
         tx.valid <= '1';
         tx.data  <= (others => '0');
         tx.data(R_MAC_DST)  <= X"FFFFFFFFFFFF";
         tx.data(R_MAC_SRC)  <= X"66778899AABB";
         tx.data(R_MAC_TLEN) <= X"0806";
         tx.data(R_ARP_HDR)  <= X"0001080006040001";
         tx.data(R_ARP_SHA)  <= X"AABBCCDDEEFF";
         tx.data(R_ARP_SPA)  <= X"C0A80101";
         tx.data(R_ARP_THA)  <= X"000000000000";
         tx.data(R_ARP_TPA)  <= C_DUT_IP;
         tx.last  <= '1';
         tx.bytes <= (others => '0');       -- Frame size 60 bytes.
         wait until clk = '1';
         tx.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(R_MAC_DST)  <= X"66778899AABB";
         exp.data(R_MAC_SRC)  <= C_DUT_MAC;
         exp.data(R_MAC_TLEN) <= X"0806";
         exp.data(R_ARP_HDR)  <= X"0001080006040002";
         exp.data(R_ARP_SHA)  <= C_DUT_MAC;
         exp.data(R_ARP_SPA)  <= C_DUT_IP;
         exp.data(R_ARP_THA)  <= X"AABBCCDDEEFF";
         exp.data(R_ARP_TPA)  <= X"C0A80101";
         exp.last  <= '1';
         exp.bytes <= (others => '0');

         -- Verify ARP response is correct
         wait until clk = '1' and rx.valid = '1';
         wait until clk = '0';
         assert rx.data  = exp.data;
         assert rx.last  = exp.last;
         assert rx.bytes = exp.bytes;
      end procedure verify_arp;

   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until rst = '0';
      wait until eth_rstn = '1';
      wait until clk = '1';

      verify_arp(sim_tx, sim_rx);

      -- Wait a little while to ease debugging                                               
      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

