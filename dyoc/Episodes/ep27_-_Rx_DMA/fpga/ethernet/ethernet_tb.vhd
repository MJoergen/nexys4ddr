library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;

-- This module is a test bench for the Ethernet module.

entity ethernet_tb is
end entity ethernet_tb;

architecture structural of ethernet_tb is

   -- Connected to DUT
   signal user_clk               : std_logic;  -- 25 MHz
   signal user_rst               : std_logic;
   signal user_rxdma_ram_wr_en   : std_logic;
   signal user_rxdma_ram_wr_addr : std_logic_vector(15 downto 0);
   signal user_rxdma_ram_wr_data : std_logic_vector( 7 downto 0);
   signal user_rxdma_ptr         : std_logic_vector(15 downto 0);
   signal user_rxdma_enable      : std_logic;
   signal user_rxdma_clear       : std_logic;
   signal user_rxdma_pending     : std_logic_vector( 7 downto 0);
   signal user_rxcnt_good        : std_logic_vector(15 downto 0);
   signal user_rxcnt_error       : std_logic_vector( 7 downto 0);
   signal user_rxcnt_crc_bad     : std_logic_vector( 7 downto 0);
   signal user_rxcnt_overflow    : std_logic_vector( 7 downto 0);
   --
   signal eth_clk           : std_logic;  -- 50 MHz
   signal eth_refclk        : std_logic;
   signal eth_rstn          : std_logic;
   signal eth_rxd           : std_logic_vector(1 downto 0);
   signal eth_crsdv         : std_logic;

   -- Controls the traffic input to Ethernet.
   signal sim_data  : std_logic_vector(1600*8-1 downto 0);
   signal sim_len   : std_logic_vector(  15     downto 0);
   signal sim_start : std_logic := '0';
   signal sim_done  : std_logic;

   -- Used to clear the sim_ram between each test.
   signal sim_ram_in    : std_logic_vector(16383 downto 0);
   signal sim_ram_out   : std_logic_vector(16383 downto 0);
   signal sim_ram_init  : std_logic;

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

   -- Generate cpu reset
   proc_user_rst : process
   begin
      user_rst <= '1', '0' after 200 ns;
      wait;
   end process proc_user_rst;

   -- Generate eth clock @ 50 MHz
   proc_eth_clk : process
   begin
      eth_clk <= '1', '0' after 10 ns;
      wait for 20 ns;

      if sim_test_running = '0' then
         wait;
      end if;
   end process proc_eth_clk;


   ---------------------------------
   -- Instantiate ram simulator
   ---------------------------------

   inst_ram_sim : entity work.ram_sim
   port map (
      clk_i      => user_clk,
      wr_en_i    => user_rxdma_ram_wr_en,
      wr_addr_i  => user_rxdma_ram_wr_addr,
      wr_data_i  => user_rxdma_ram_wr_data,
      ram_init_i => sim_ram_init,
      ram_in_i   => sim_ram_in,
      ram_out_o  => sim_ram_out
   );


   ---------------------------------
   -- Instantiate PHY simulator
   ---------------------------------

   inst_phy_sim : entity work.phy_sim
   port map (
      sim_data_i   => sim_data,
      sim_len_i    => sim_len,
      sim_start_i  => sim_start,
      sim_done_o   => sim_done,
      --
      eth_refclk_i => eth_refclk,
      eth_rstn_i   => eth_rstn,
      eth_txd_o    => eth_rxd,
      eth_txen_o   => eth_crsdv
   );


   -------------------
   -- Instantiate DUT
   -------------------

   inst_ethernet : entity work.ethernet
   port map (
      main_clk_i               => user_clk,
      main_rst_i               => user_rst,
      main_rxdma_ram_wr_en_o   => user_rxdma_ram_wr_en,
      main_rxdma_ram_wr_addr_o => user_rxdma_ram_wr_addr,
      main_rxdma_ram_wr_data_o => user_rxdma_ram_wr_data,
      main_rxdma_ptr_i         => user_rxdma_ptr,
      main_rxdma_enable_i      => user_rxdma_enable,
      main_rxdma_clear_o       => user_rxdma_clear,
      main_rxdma_pending_o     => user_rxdma_pending,
      --
      eth_rxcnt_good_o        => user_rxcnt_good,
      eth_rxcnt_error_o       => user_rxcnt_error,
      eth_rxcnt_crc_bad_o     => user_rxcnt_crc_bad,
      eth_rxcnt_overflow_o    => user_rxcnt_overflow,
      --
      eth_clk_i           => eth_clk,
      eth_txd_o           => open,   -- We're ignoring transmit for now
      eth_txen_o          => open,   -- We're ignoring transmit for now
      eth_rxd_i           => eth_rxd,
      eth_rxerr_i         => '0',
      eth_crsdv_i         => eth_crsdv,
      eth_intn_i          => '0',
      eth_mdio_io         => open,
      eth_mdc_o           => open,
      eth_rstn_o          => eth_rstn,
      eth_refclk_o        => eth_refclk
   );
   

   --------------------
   -- Main test program
   --------------------

   proc_test : process

      procedure send_frame(first : integer; length : integer) is
      begin
         sim_len <= to_std_logic_vector(length, 16);
         sim_data <= (others => 'X');
         for i in 0 to length-1 loop
            sim_data(8*i+7 downto 8*i) <= 
               to_std_logic_vector((i+first) mod 256, 8);
         end loop;
         sim_start <= '1';

         -- Wait until data has been transferred on PHY signals
         wait until sim_done = '1';
         sim_start <= '0';
         wait until eth_refclk = '1';
      end procedure send_frame;

      procedure verify_frame(first : integer; length : integer) is
      begin
         assert sim_ram_out(15 downto 0) = to_std_logic_vector(length, 16);

         for i in 0 to length-1 loop
            assert sim_ram_out((i+2)*8+7 downto (i+2)*8) = to_std_logic_vector((i+first) mod 256, 8)
               report "i=" & integer'image(i);
         end loop;
         assert sim_ram_out((length+2)*8+7 downto (length+2)*8) = "XXXXXXXX";
      end procedure verify_frame;

   begin
      -- Wait for reset
      sim_start         <= '0';
      user_rxdma_enable <= '0';
      user_rxdma_ptr    <= (others => '0');
      wait until eth_rstn = '1';

      -- Configure DMA for 1700 bytes of receive buffer space
      user_rxdma_ptr <= X"2000";

      -- Clear ram
      wait until user_clk = '1';
      sim_ram_in <= (others => 'X');
      sim_ram_init <= '1';
      wait until user_clk = '1';
      sim_ram_init <= '0';

      assert user_rxdma_clear = '0';
      assert user_rxdma_pending = X"00";

      -----------------------------------------------
      -- Test 1 : Receive one frame
      -- Expected behaviour: Frame is written to memory
      -----------------------------------------------
      report "Starting test 1";

      -- Enable DMA
      user_rxdma_enable <= '1';

      -- Send frame
      send_frame(first => 64, length => 100);

      -- Wait until frame has been received
      wait until user_rxdma_clear = '1';
      wait until user_clk = '1';
      user_rxdma_enable <= '0';
      wait until user_clk = '1';
      wait until user_clk = '1';
      assert user_rxdma_clear = '0';
      assert user_rxdma_pending = X"00";

      -- Verify statistics counters
      assert user_rxcnt_good     = 1;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 0;

      -- Verify memory contents.
      verify_frame(first => 64, length => 100);


      -----------------------------------------------
      -- Test 2 : Receive two frames back-to-back
      -- Expected behaviour: One frame is written to memory.
      -----------------------------------------------
      report "Starting test 2";

      -- Enable DMA
      user_rxdma_enable <= '1';

      -- Send two frames
      send_frame(first => 80, length => 110);
      send_frame(first => 90, length => 120);

      wait for 5 us;

      -- Wait until first frame has been received
      assert user_rxdma_pending = X"01";
      if user_rxdma_clear = '0' then
         wait until user_rxdma_clear = '1';
      end if;
      wait until user_clk = '1';
      user_rxdma_enable <= '0';
      wait until user_clk = '1';
      wait until user_clk = '1';
      assert user_rxdma_clear = '0';

      -- Verify statistics counters
      assert user_rxcnt_good     = 3;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 0;

      -- Verify first frame
      verify_frame(first => 80, length => 110);


      -----------------------------------------------
      -- Test 3 : Enable DMA again
      -- Expected behaviour: Second frame is received
      -----------------------------------------------
      report "Starting test 3";

      -- Enable DMA
      user_rxdma_enable <= '1';

      -- Wait until second frame has been received
      assert user_rxdma_pending = X"01";
      if user_rxdma_clear = '0' then
         wait until user_rxdma_clear = '1';
      end if;
      wait until user_clk = '1';
      user_rxdma_enable <= '0';
      wait until user_clk = '1';
      wait until user_clk = '1';
      assert user_rxdma_clear = '0';

      -- Verify statistics counters are unchanged
      assert user_rxcnt_good     = 3;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 0;
      assert user_rxdma_pending  = X"00";

      -- Verify second frame
      verify_frame(first => 90, length => 120);


      -----------------------------------------------
      -- Test 4 : Receive 1515 byte frame
      -- Expected behaviour: Frame is discarded
      -----------------------------------------------
      report "Starting test 4";

      -- Enable DMA
      user_rxdma_enable <= '1';

      -- Clear ram
      wait until user_clk = '1';
      sim_ram_init <= '1';
      wait until user_clk = '1';
      sim_ram_init <= '0';

      -- Send oversize frame
      send_frame(first => 70, length => 1515);

      -- Wait until frame has been received
      wait for 10 us;
      wait until user_clk = '1';

      assert user_rxdma_clear   = '0';
      assert user_rxdma_enable  = '1';
      assert user_rxdma_pending = X"00";

      -- Verify statistics counters
      assert user_rxcnt_good     = 3;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 1;

      -- Verify nothing is received
      assert sim_ram_out(7 downto 0) = "XXXXXXXX";


      -----------------------------------------------
      -- Test 5 : Receive one 1514 byte frame
      -- Expected behaviour: Frame is written to memory
      -----------------------------------------------
      report "Starting test 5";

      -- Enable DMA
      user_rxdma_enable <= '1';

      -- Send frame
      send_frame(first => 34, length => 1514);

      -- Wait until frame has been received
      wait until user_rxdma_clear = '1';
      wait until user_clk = '1';
      user_rxdma_enable <= '0';
      wait until user_clk = '1';
      wait until user_clk = '1';
      assert user_rxdma_clear = '0';

      -- Verify statistics counters
      assert user_rxcnt_good     = 4;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 1;
      assert user_rxdma_pending  = X"00";

      -- Verify memory contents.
      verify_frame(first => 34, length => 1514);


      -----------------------------------------------
      -- END OF TEST
      -----------------------------------------------

      report "Test completed";
      sim_test_running <= '0';
      wait;

   end process proc_test;

end structural;

