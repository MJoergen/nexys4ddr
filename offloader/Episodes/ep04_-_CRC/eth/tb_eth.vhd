library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

entity tb_eth is
end tb_eth;

architecture simulation of tb_eth is

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
   signal debug     : std_logic_vector(255 downto 0);

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

   -- Common procedure to test a given frame size.
   procedure test_frame(constant size : in    integer;
                        signal   tx   : inout t_sim;
                        signal   rx   : in    std_logic_vector(255 downto 0)) is
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

      wait for size*20 ns;

      -- Validate received frame
      if size > 32+10 then
         assert rx(32*8-1 downto 0)           = tx.data(50*8-1 downto 50*8-32*8);
      else
         assert rx(32*8-1 downto 32*8-(size-10)*8) = tx.data(50*8-1 downto 50*8-(size-10)*8);
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
      eth_txd_o    => open,
      eth_txen_o   => open,
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
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process
   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until rst = '0';
      wait until eth_rstn = '1';
      wait until clk = '1';

      test_frame(16, sim_tx, debug);
      wait for 100 ns; -- Make a short pause for easier debugging.
      test_frame(32, sim_tx, debug);
      wait for 100 ns; -- Make a short pause for easier debugging.
      test_frame(42, sim_tx, debug);
      wait for 100 ns; -- Make a short pause for easier debugging.
      test_frame(43, sim_tx, debug);
      wait for 100 ns; -- Make a short pause for easier debugging.
      test_frame(60, sim_tx, debug);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

