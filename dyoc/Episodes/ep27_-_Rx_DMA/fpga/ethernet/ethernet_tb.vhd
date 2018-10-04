library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

-- This module is a test bench for the Ethernet module.

entity ethernet_tb is
end entity ethernet_tb;

architecture Structural of ethernet_tb is

   -- Connected to DUT
   signal user_clk       : std_logic;  -- 25 MHz
   signal user_wren      : std_logic;
   signal user_addr      : std_logic_vector(15 downto 0);
   signal user_data      : std_logic_vector( 7 downto 0);
   signal user_memio_in  : std_logic_vector(55 downto 0);
   signal user_memio_out : std_logic_vector(55 downto 0);
   signal eth_clk        : std_logic;  -- 50 MHz
   signal eth_rst        : std_logic;
   signal eth_rxd        : std_logic_vector(1 downto 0);
   signal eth_crsdv      : std_logic;
   signal eth_rxerr      : std_logic;
   signal eth_rstn       : std_logic;
   signal eth_refclk     : std_logic;

   alias user_rxdma_start  : std_logic_vector(15 downto 0) is user_memio_in( 15 downto  0);
   alias user_rxdma_end    : std_logic_vector(15 downto 0) is user_memio_in( 31 downto 16);
   alias user_rxdma_rdptr  : std_logic_vector(15 downto 0) is user_memio_in( 47 downto 32);
   alias user_rxdma_enable : std_logic                     is user_memio_in( 48);
   alias user_rxdma_wrptr  : std_logic_vector(15 downto 0) is user_memio_out(15 downto  0);
   alias user_cnt_good     : std_logic_vector(15 downto 0) is user_memio_out(31 downto 16);
   alias user_cnt_error    : std_logic_vector( 7 downto 0) is user_memio_out(39 downto 32);
   alias user_cnt_crc_bad  : std_logic_vector( 7 downto 0) is user_memio_out(47 downto 40);
   alias user_cnt_overflow : std_logic_vector( 7 downto 0) is user_memio_out(55 downto 48);

   -- Controls the traffic input to Ethernet.
   signal sim_data  : std_logic_vector(128*8-1 downto 0);
   signal sim_len   : std_logic_vector( 15     downto 0);
   signal sim_start : std_logic := '0';
   signal sim_done  : std_logic;

   -- Used to clear the sim_ram between each test.
   signal sim_ram       : std_logic_vector(16383 downto 0);
   signal sim_ram_clear : std_logic;

   -- Control the execution of the test.
   signal sim_test_running : std_logic := '1';

begin

   -----------------------------
   -- Generate clock and reset
   -----------------------------

   -- Generate cpu clock @ 25 MHz
   proc_user_clk : process
   begin
      user_clk <= '1', '0' after 20 ns;
      wait for 40 ns;
      if sim_test_running = '0' then
         wait;
      end if;
   end process proc_user_clk;

   -- Generate eth clock @ 50 MHz
   proc_eth_clk : process
   begin
      eth_clk <= '1', '0' after 10 ns;
      wait for 20 ns;
      if sim_test_running = '0' then
         wait;
      end if;
   end process proc_eth_clk;

   -- Generate eth reset for 5 clock cycles
   proc_eth_rst : process
   begin
      eth_rst <= '1', '0' after 100 ns;
      wait;
   end process proc_eth_rst;


   ---------------------------------
   -- Instantiate sim_ram simulator
   ---------------------------------

   inst_ram_sim : entity work.ram_sim
   port map (
      clk_i   => user_clk,
      wren_i  => user_wren,
      addr_i  => user_addr,
      data_i  => user_data,
      clear_i => sim_ram_clear,
      ram_o   => sim_ram
   );


   ---------------------------------
   -- Instantiate PHY simulator
   ---------------------------------

   inst_phy_sim : entity work.phy_sim
   port map (
      clk_i      => eth_clk,
      rst_i      => eth_rst,
      data_i     => sim_data,
      len_i      => sim_len,
      start_i    => sim_start,
      done_o     => sim_done,
      eth_txd_o  => eth_rxd,
      eth_txen_o => eth_crsdv
   );


   -------------------
   -- Instantiate DUT
   -------------------

   inst_ethernet : entity work.ethernet
   port map (
      user_clk_i   => user_clk,
      user_wren_o  => user_wren,
      user_addr_o  => user_addr,
      user_data_o  => user_data,
      user_memio_i => user_memio_in,
      user_memio_o => user_memio_out,
      eth_clk_i    => eth_clk,
      eth_txd_o    => open,   -- We're ignoring transmit for now
      eth_txen_o   => open,   -- We're ignoring transmit for now
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => eth_rxerr,
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => eth_refclk
   );
   

   --------------------
   -- Main test program
   --------------------

   proc_test : process
   begin
      -- Wait for reset
      sim_start     <= '0';
      user_memio_in <= (others => '0');
      wait until eth_rst = '0';

      -- Clear sim_ram
      wait until user_clk = '0';
      sim_ram_clear <= '1';
      wait until user_clk = '1';
      sim_ram_clear <= '0';

      -- Disable DMA (prepare for DMA configuration)
      user_rxdma_enable <= '0';
      wait until user_clk = '1';

      -----------------------------------------------
      -- Test 1 : Receive first frame while DMA is disabled
      -- Expected behaviour: Frame is discarded
      -----------------------------------------------

      -- Wait while test runs
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+32, 8));
      end loop;
      sim_len   <= X"0011"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait for 3 us;             -- Wait until data has been received in sim_ram.

      -- Verify statistics counters
      assert user_cnt_good     = 0;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;


      -----------------------------------------------
      -- Test 2 : Enable DMA
      -- Expected behaviour: DMA write pointer updated
      -----------------------------------------------

      -- Configure DMA for 1600 bytes of receive buffer space
      user_rxdma_start <= X"2000";
      user_rxdma_end   <= X"2000" + 1700;
      user_rxdma_rdptr <= X"2000";
      wait until user_clk = '1';
      user_rxdma_enable <= '1';
      wait until user_clk = '1';

      assert user_rxdma_wrptr = X"2000";


      -----------------------------------------------
      -- Test 3 : Receive second frame
      -- Expected behaviour: Frame is written to memory
      --                     Write pointer is updated
      -----------------------------------------------

      -- Send frame
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+32, 8));
      end loop;
      sim_len   <= X"0080"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait until user_rxdma_wrptr /= X"2000";  -- Wait until RxDMA is finished

      -- Verify DMA write pointer
      assert user_rxdma_wrptr = X"2082";

      -- Verify statistics counters
      assert user_cnt_good     = 1;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify memory contents.
      assert sim_ram(15 downto 0) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+2)*8+7 downto (i+2)*8) = std_logic_vector(to_unsigned(i+32, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(130*8+7 downto 130*8) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 4 : Receive third frame
      -- Expected behaviour: Frame is written to memory
      --                     Write pointer is now end of buffer
      -----------------------------------------------

      -- Send frame
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+64, 8));
      end loop;
      sim_len   <= X"0080"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait until user_rxdma_wrptr /= X"2082";  -- Wait until RxDMA is finished

      -- Verify DMA write pointer
      assert user_rxdma_wrptr = user_rxdma_end;

      -- Verify statistics counters
      assert user_cnt_good     = 2;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify memory contents.
      assert sim_ram(15 downto 0) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+2)*8+7 downto (i+2)*8) = std_logic_vector(to_unsigned(i+32, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(130*8+15 downto 130*8) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+132)*8+7 downto (i+132)*8) = std_logic_vector(to_unsigned(i+64, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(260*8+7 downto 260*8) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 5 : Receive fourth frame
      -- Expected behaviour: Frame is held back
      -----------------------------------------------

      -- Send frame
      for i in 0 to 127 loop
         sim_data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+96, 8));
      end loop;
      sim_len   <= X"0080"; -- Number of bytes to send
      sim_start <= '1';
      wait until sim_done = '1';  -- Wait until data has been transferred on PHY signals
      sim_start <= '0';
      wait for 10 us;            -- Wait some time while RxDMA processes data.

      -- Verify DMA write pointer is untouched.
      assert user_rxdma_wrptr = user_rxdma_end;

      -- Verify statistics counters
      assert user_cnt_good     = 3;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify previous frames are untouched.
      assert sim_ram(15 downto 0) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+2)*8+7 downto (i+2)*8) = std_logic_vector(to_unsigned(i+32, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(130*8+15 downto 130*8) = X"0082";  -- Length includes 2-byte header.
      for i in 0 to 127 loop
         assert sim_ram((i+132)*8+7 downto (i+132)*8) = std_logic_vector(to_unsigned(i+64, 8)) report "i=" & integer'image(i);
      end loop;
      assert sim_ram(260*8+7 downto 260*8) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 6 : Update CPU read pointer
      -- Expected behaviour: Frame is written to memory
      -----------------------------------------------

      -- Update CPU read pointer
      user_rxdma_rdptr <= X"2082";
      wait until user_rxdma_wrptr /= user_rxdma_end; -- Wait until frame has been transferred to sim_ram.

      -- Verify DMA write pointer is updated
      assert user_rxdma_wrptr = user_rxdma_rdptr;

      -- Verify statistics counters
      assert user_cnt_good     = 3;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

      -- Verify first frame is untouched.


      -----------------------------------------------
      -- END OF TEST
      -----------------------------------------------

      report "Test completed";
      sim_test_running <= '0';
      wait;

   end process proc_test;

end Structural;

