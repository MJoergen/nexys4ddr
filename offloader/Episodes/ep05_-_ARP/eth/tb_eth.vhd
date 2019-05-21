library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet Rx and Tx interface
-- modules. The purpose is to verify the modules connecting to the PHY.
--
-- The testbench performs the following:
-- * Generates Ethernet frames for transmission
-- * Sends the frames through the transmit path of the interface module (eth_tx).
-- * Performs a loopback on the PHY side of the interface module.
-- * Stores the frames from the receive path of the interface module (eth_rx).
-- * Compares the received frames with the transmitted frames.

entity tb_eth is
end tb_eth;

architecture simulation of tb_eth is

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx_valid : std_logic;
   signal sim_tx_size  : std_logic_vector(7 downto 0);
   signal sim_tx_data  : std_logic_vector(64*8-1 downto 0);

   -- Input to eth_tx
   signal tx_empty     : std_logic;
   signal tx_rden      : std_logic;
   signal tx_data      : std_logic_vector(7 downto 0);
   signal tx_sof       : std_logic;
   signal tx_eof       : std_logic;

   -- Signals conected to DUT
   signal eth_rstn     : std_logic;
   signal eth_rxd      : std_logic_vector(1 downto 0);
   signal eth_crsdv    : std_logic;
   signal eth_txd      : std_logic_vector(1 downto 0);
   signal eth_txen     : std_logic;
   signal debug        : std_logic_vector(255 downto 0);

   -- Input to eth_rx
   signal rx_valid     : std_logic;
   signal rx_sof       : std_logic;
   signal rx_eof       : std_logic;
   signal rx_data      : std_logic_vector(7 downto 0);
   signal rx_ok        : std_logic;

   -- Signals for reception of the Ethernet frames.
   signal sim_rx_valid : std_logic;
   signal sim_rx_size  : std_logic_vector(7 downto 0);
   signal sim_rx_data  : std_logic_vector(64*8-1 downto 0);

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
      G_PL_SIZE  => 64
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      pl_valid_i => sim_tx_valid,
      pl_size_i  => sim_tx_size,
      pl_data_i  => sim_tx_data,
      --
      tx_empty_o => tx_empty,
      tx_data_o  => tx_data,
      tx_sof_o   => tx_sof,
      tx_eof_o   => tx_eof,
      tx_rden_i  => tx_rden
   ); -- i_wide2byte

   i_eth_tx : entity work.eth_tx
   port map (
      eth_clk_i  => clk,
      eth_rst_i  => rst,
      tx_data_i  => tx_data,
      tx_sof_i   => tx_sof,
      tx_eof_i   => tx_eof,
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
      rx_sof_o    => rx_sof,
      rx_eof_o    => rx_eof,
      rx_data_o   => rx_data,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_byte2wide : entity work.byte2wide
   generic map (
      G_HDR_SIZE  => 64
   )
   port map (
      clk_i       => clk,
      rst_i       => rst,
      rx_valid_i  => rx_valid,
      rx_sof_i    => rx_sof,
      rx_eof_i    => rx_eof,
      rx_data_i   => rx_data,
      hdr_valid_o => sim_rx_valid,
      hdr_data_o  => sim_rx_data,
      hdr_size_o  => sim_rx_size,
      hdr_more_o  => open,
      pl_valid_o  => open, 
      pl_eof_o    => open, 
      pl_data_o   => open 
   ); -- i_byte2wide


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process
   begin
      -- Wait until reset is complete
      sim_tx_valid <= '0';
      wait until rst = '0';
      wait until eth_rstn = '1';
      wait until clk = '1';

      -- Send one ARP request
      sim_tx_data <= (others => '0');
      sim_tx_data(64*8-1 downto 64*8-42*8) <= X"FFFFFFFFFFFF66778899AABB0806" &  -- MAC header
                                              X"0001080006040001" &              -- ARP header
                                              X"AABBCCDDEEFF" & X"C0A80001" &    -- SHA & SPA
                                              X"000000000000" & X"C0A8014D";     -- THA & TPA
      sim_tx_size  <= X"3C";
      sim_tx_valid <= '1';
      wait until clk = '1';
      sim_tx_valid <= '0';

      -- Verify ARP response is correct
      wait until sim_rx_valid = '1';
      assert sim_rx_size = sim_tx_size + 4;
      assert sim_rx_data(64*8-1 downto 64*8-42*8) = X"66778899AABB0011223344550806" &  -- MAC header
                                                    X"0001080006040002" &              -- ARP header
                                                    X"001122334455" & X"C0A8014D" &    -- THA & TPA
                                                    X"AABBCCDDEEFF" & X"C0A80001";     -- SHA & SPA
      assert debug = sim_rx_data(64*8-42*8+32*8-1 downto 64*8-42*8);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

