library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This is a testbench for the LAN8720A Ethernet PHY. The purpose
-- is to verify the interface to the PHY.

entity lan8720a_tb is
end lan8720a_tb;

architecture simulation of lan8720a_tb is

   -- Signals connected to DUT.
   signal clk       : std_logic;
   signal rst       : std_logic;
   signal rx_valid  : std_logic;
   signal rx_sof    : std_logic;
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

   signal start : std_logic;
   signal done  : std_logic;
   signal len   : std_logic_vector(15 downto 0);
   signal data  : std_logic_vector(128*8-1 downto 0);

   signal test_running : std_logic := '1';

begin

   -- Generate clock
   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns;
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   -- Generate reset
   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;


   -----------------------------
   -- Generate data to send
   -----------------------------

   sim_tx_proc : process
   begin
      tx_empty <= '1';
      tx_data  <= (others => '0');
      tx_eof   <= '0';
      done     <= '1';

      wait until start = '1';
      done     <= '0';
      tx_empty <= '0';

      byte_loop : for i in 0 to conv_integer(len)-1 loop
         tx_data <= data(8*i+7 downto 8*i);
         if i=conv_integer(len)-1 then
            tx_eof <= '1';
         end if;

         wait until tx_rden = '1';
      end loop byte_loop;
   end process sim_tx_proc;


   ---------------------------
   -- Validate data received
   ---------------------------

   sim_rx_proc : process
   begin
      -- Verify frame 1
      byte_loop_1 : for i in 0 to 15 loop
         wait until rx_valid = '1';
         assert rx_error = "00";

         if i = 0 then
            assert rx_sof = '1';
         end if;

         assert rx_data = std_logic_vector(to_unsigned(i+12, 8));

         if i = 15 then
            assert rx_eof = '1';
         end if;
      end loop byte_loop_1;

      -- Verify frame 2
      byte_loop_2 : for i in 0 to 31 loop
         wait until rx_valid = '1';
         assert rx_error = "00";

         if i = 0 then
            assert rx_sof = '1';
         end if;

         assert rx_data = std_logic_vector(to_unsigned(i+22, 8));

         if i = 31 then
            assert rx_eof = '1';
         end if;
      end loop byte_loop_2;

   end process sim_rx_proc;


   --------------------
   -- Instantiate the DUT
   --------------------

   inst_lan8720a : entity work.lan8720a
   port map (
      clk_i        => clk,
      rst_i        => rst,
      rx_valid_o   => rx_valid,
      rx_sof_o     => rx_sof,
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


   ----------------------------------
   -- Main test procedure starts here
   ----------------------------------

   main_test_proc : process
   begin
      -- Wait until reset is complete
      start <= '0';
      wait until rst = '0';
      wait until clk = '1';

      -- Send one frame (16 bytes)
      for i in 0 to 127 loop
         data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+12, 8));
      end loop;
      len   <= X"0010";
      start <= '1';
      wait until done = '1';
      start <= '0';
      wait until rx_valid = '1' and rx_eof = '1';

      -- Send another frame (32 bytes)
      for i in 0 to 127 loop
         data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+22, 8));
      end loop;
      len   <= X"0020";
      start <= '1';
      wait until done = '1';
      start <= '0';
      wait until rx_valid = '1' and rx_eof = '1';
      wait until clk = '1';

      -- Stop test
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

