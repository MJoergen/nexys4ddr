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

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk      : std_logic;
   signal rst      : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx : t_sim;

   -- Output from wide2byte
   signal tx_empty : std_logic;
   signal tx_rden  : std_logic;
   signal tx_data  : std_logic_vector(7 downto 0);
   signal tx_last  : std_logic;

   -- Signals conected to PHY
   signal eth_d    : std_logic_vector(1 downto 0);
   signal eth_en   : std_logic;

   -- Output from eth_rx
   signal rx_valid : std_logic;
   signal rx_last  : std_logic;
   signal rx_data  : std_logic_vector(7 downto 0);
   signal rx_ok    : std_logic;

   -- Signals for reception of the Ethernet frames.
   signal sim_rx : t_sim;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

   -- Common procedure to test a given frame size.
   procedure test_frame(constant size : in    integer;
                        signal   tx   : inout t_sim;
                        signal   rx   : in    t_sim) is
   begin
      report "Testing frame size " & integer'image(size);

      -- Send one frame
      wait until clk = '0';
      tx.data <= (others => 'U');
      for i in 0 to size-1 loop
         tx.data(60*8-1-8*i downto 60*8-8-8*i) <= to_std_logic_vector(i+12, 8);
      end loop;
      tx.bytes <= to_stdlogicvector(size, 6);
      tx.last  <= '1';
      tx.valid <= '1';
      wait until clk = '1';
      tx.valid <= '0';

      -- Validate received frame
      wait until clk = '1' and rx.valid = '1';
      wait until clk = '0';
      if size < 56 then
         assert rx.bytes = size + 4;   -- The received frame includes CRC.
      else
         assert rx.bytes = 0;
      end if;
      if size < 60 then
         assert rx.data(60*8-1 downto 60*8-size*8) = tx.data(60*8-1 downto 60*8-size*8);
      else
         assert rx.data(60*8-1 downto 0)           = tx.data(60*8-1 downto 0);
      end if;
   end procedure test_frame;

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
      eth_txd_o  => eth_d,
      eth_txen_o => eth_en
   ); -- i_eth_tx


   --------------------------------------------------
   -- Instantiate traffic receiver
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => clk,
      eth_rst_i   => rst,
      eth_rxd_i   => eth_d,
      eth_crsdv_i => eth_en,
      eth_rxerr_i => '0',
      --
      rx_valid_o  => rx_valid,
      rx_data_o   => rx_data,
      rx_last_o   => rx_last,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_byte2wide : entity work.byte2wide
   generic map (
      G_BYTES    => 60
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => rx_valid,
      rx_data_i  => rx_data,
      rx_last_i  => rx_last,
      --
      tx_valid_o => sim_rx.valid,
      tx_data_o  => sim_rx.data,
      tx_last_o  => sim_rx.last,
      tx_bytes_o => sim_rx.bytes
   ); -- i_byte2wide


   -- Verify that all received frames are reported as OK, i.e. correct CRC
   p_verify_ok : process (clk)
   begin
      if rising_edge(clk) then
         if rx_valid = '1' and rx_last = '1' then
            assert rx_ok = '1';
         end if;
      end if;
   end process p_verify_ok;


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process
   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until rst = '0';
      wait until clk = '1';

      test_frame(16, sim_tx, sim_rx);

      wait for 100 ns; -- Make a short pause for easier debugging.

      test_frame(32, sim_tx, sim_rx);

      wait for 100 ns; -- Make a short pause for easier debugging.

      test_frame(55, sim_tx, sim_rx);

      wait for 100 ns; -- Make a short pause for easier debugging.

      test_frame(56, sim_tx, sim_rx);

      wait for 100 ns; -- Make a short pause for easier debugging.

      test_frame(57, sim_tx, sim_rx);

      wait for 100 ns; -- Make a short pause for easier debugging.

      test_frame(59, sim_tx, sim_rx);

      wait for 100 ns; -- Make a short pause for easier debugging.

      test_frame(60, sim_tx, sim_rx);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

