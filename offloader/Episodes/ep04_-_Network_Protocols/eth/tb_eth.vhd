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

   signal clk       : std_logic;
   signal rst       : std_logic;

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
   signal eth_d        : std_logic_vector(1 downto 0);
   signal eth_en       : std_logic;
   signal debug        : std_logic_vector(255 downto 0);

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
      pl_data_i  => sim_tx_data,
      pl_size_i  => sim_tx_size,
      --
      tx_empty_o => tx_empty,
      tx_data_o  => tx_data,
      tx_sof_o   => tx_sof,
      tx_eof_o   => tx_eof,
      tx_rden_i  => tx_rden
   ); -- i_wide2byte


   --------------------------------------------------
   -- Instantiate Tx path
   --------------------------------------------------

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
      eth_txd_o  => eth_d,
      eth_txen_o => eth_en
   ); -- i_eth_tx


   --------------------------------------------------
   -- Instantiate DUT
   --------------------------------------------------

   i_eth : entity work.eth
   port map (
      clk_i        => clk,
      debug_o      => debug,
      eth_txd_o    => open,
      eth_txen_o   => open,
      eth_rxd_i    => eth_d,
      eth_rxerr_i  => '0',
      eth_crsdv_i  => eth_en,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => open
   ); -- i_eth


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

      -- Send one frame (16 bytes)
      sim_tx_data <= (others => 'U');
      for i in 0 to 15 loop
         sim_tx_data(64*8-1-8*i downto 64*8-8-8*i) <= to_std_logic_vector(i+12, 8);
      end loop;
      sim_tx_size  <= X"10";
      sim_tx_valid <= '1';
      wait until clk = '1';
      sim_tx_valid <= '0';

      -- Make a short pause while frame is being received.
      wait for 400 ns;

      -- Validate received frame
      assert debug(32*8-1 downto 32*8-16*8) = sim_tx_data(64*8-1 downto 64*8-16*8);

      -- Send another frame (32 bytes)
      sim_tx_data <= (others => 'U');
      for i in 0 to 31 loop
         sim_tx_data(64*8-1-8*i downto 64*8-8-8*i) <= to_std_logic_vector(i+22, 8);
      end loop;
      sim_tx_size  <= X"20";
      sim_tx_valid <= '1';
      wait until clk = '1';
      sim_tx_valid <= '0';

      -- Make a short pause while frame is being received.
      wait for 500 ns;

      -- Validate received frame
      assert debug(32*8-1 downto 0) = sim_tx_data(64*8-1 downto 64*8-32*8);


      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

