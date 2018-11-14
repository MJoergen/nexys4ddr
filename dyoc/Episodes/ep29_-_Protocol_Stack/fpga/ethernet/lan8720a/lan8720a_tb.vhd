library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a testbench for the LAN8720A Ethernet PHY. The purpose
-- is to verify the interface to the PHY.
--
-- The testbench performs the following:
-- * Generates Ethernet frames for transmission
-- * Sends the frames through the transmit path of the interface module.
-- * Performs a loopback on the PHY side of the interface module.
-- * Stores the frames from the receive path of the interface module.
-- * Compares the received frames with the transmitted frames.

entity lan8720a_tb is
end lan8720a_tb;

architecture simulation of lan8720a_tb is

   -- Signals connected to DUT.
   signal clk       : std_logic;
   signal rst       : std_logic;
   signal rx_valid  : std_logic;
   signal rx_eof    : std_logic;
   signal rx_data   : std_logic_vector(7 downto 0);
   signal rx_error  : std_logic_vector(1 downto 0);
   signal tx_empty  : std_logic;
   signal tx_rden   : std_logic;
   signal tx_data   : std_logic_vector(7 downto 0);
   signal tx_eof    : std_logic;
   signal tx_err    : std_logic;
   signal eth_rxd   : std_logic_vector(1 downto 0);
   signal eth_crsdv : std_logic;
   signal eth_txd   : std_logic_vector(1 downto 0);
   signal eth_txen  : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx_start : std_logic;
   signal sim_tx_done  : std_logic;
   signal sim_tx_len   : std_logic_vector(15 downto 0);
   signal sim_tx_data  : std_logic_vector(128*8-1 downto 0);

   -- Signals for reception of the Ethernet frames.
   signal sim_rx_len   : std_logic_vector(15 downto 0);
   signal sim_rx_data  : std_logic_vector(128*8-1 downto 0);

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns;
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;


   ---------------------------------
   -- Instantiate traffic generator
   ---------------------------------

   inst_sim_tx : entity work.sim_tx
   port map (
      sim_start_i => sim_tx_start,
      sim_data_i  => sim_tx_data,
      sim_len_i   => sim_tx_len,
      sim_done_o  => sim_tx_done,

      tx_empty_o  => tx_empty,
      tx_data_o   => tx_data,
      tx_eof_o    => tx_eof,
      tx_rden_i   => tx_rden
   );


   --------------------
   -- Instantiate the DUT
   --------------------

   inst_lan8720a : entity work.lan8720a
   port map (
      clk_i        => clk,
      rst_i        => rst,
      rx_valid_o   => rx_valid,
      rx_eof_o     => rx_eof,
      rx_data_o    => rx_data,
      rx_error_o   => rx_error,
      tx_empty_i   => tx_empty,
      tx_rden_o    => tx_rden,
      tx_data_i    => tx_data,
      tx_eof_i     => tx_eof,
      tx_err_o     => tx_err,
      eth_txd_o    => eth_txd,
      eth_txen_o   => eth_txen,
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => '0',
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
      eth_rstn_o   => open,
      eth_refclk_o => open
   );


   ------------
   -- Loopback
   ------------

   eth_rxd   <= eth_txd;
   eth_crsdv <= eth_txen;


   ---------------------------------
   -- Instantiate traffic receiver
   ---------------------------------

   inst_sim_rx : entity work.sim_rx
   port map (
      sim_data_o  => sim_rx_data,
      sim_len_o   => sim_rx_len,

      rx_valid_i  => rx_valid,
      rx_data_i   => rx_data,
      rx_eof_i    => rx_eof,
      rx_error_i  => rx_error
   );


   ----------------------------------
   -- Main test procedure starts here
   ----------------------------------

   main_test_proc : process
   begin
      -- Wait until reset is complete
      sim_tx_start <= '0';
      wait until rst = '0';
      wait until clk = '1';

      -- Send one frame (16 bytes)
      for i in 0 to 15 loop
         sim_tx_data(8*i+7 downto 8*i) <= to_std_logic_vector(i+12, 8);
      end loop;
      for i in 16 to 127 loop
         sim_tx_data(8*i+7 downto 8*i) <= (others => 'X');
      end loop;
      sim_tx_len   <= X"0010";
      sim_tx_start <= '1';
      wait until sim_tx_done = '1';
      sim_tx_start <= '0';
      wait until rx_valid = '1' and rx_eof = '1';
      wait until rx_valid = '0';
      -- Validate received frame
      assert sim_rx_len  = sim_tx_len;
      assert sim_rx_data = sim_tx_data;

      -- Send another frame (32 bytes)
      for i in 0 to 31 loop
         sim_tx_data(8*i+7 downto 8*i) <= to_std_logic_vector(i+22, 8);
      end loop;
      for i in 32 to 127 loop
         sim_tx_data(8*i+7 downto 8*i) <= (others => 'X');
      end loop;
      sim_tx_len   <= X"0020";
      sim_tx_start <= '1';
      wait until sim_tx_done = '1';
      sim_tx_start <= '0';
      wait until rx_valid = '1' and rx_eof = '1';
      wait until rx_valid = '0';
      -- Validate received frame
      assert sim_rx_len  = sim_tx_len;
      assert sim_rx_data = sim_tx_data;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

