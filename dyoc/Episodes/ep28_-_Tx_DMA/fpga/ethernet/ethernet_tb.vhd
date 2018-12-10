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
   signal user_txdma_ram_rd_en   : std_logic;
   signal user_txdma_ram_rd_addr : std_logic_vector(15 downto 0);
   signal user_txdma_ram_rd_data : std_logic_vector( 7 downto 0);
   signal user_txdma_ptr         : std_logic_vector(15 downto 0);
   signal user_txdma_enable      : std_logic;
   signal user_txdma_clear       : std_logic;
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
   signal eth_txd           : std_logic_vector(1 downto 0);
   signal eth_txen          : std_logic;

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
      rd_en_i    => user_txdma_ram_rd_en,
      rd_addr_i  => user_txdma_ram_rd_addr,
      rd_data_o  => user_txdma_ram_rd_data,
      ram_init_i => sim_ram_init,
      ram_in_i   => sim_ram_in,
      ram_out_o  => sim_ram_out
   );


   ----------------
   -- PHY loopback
   ----------------

   eth_rxd   <= eth_txd;
   eth_crsdv <= eth_txen;


   -------------------
   -- Instantiate DUT
   -------------------

   inst_ethernet : entity work.ethernet
   port map (
      main_clk_i               => user_clk,
      main_rst_i               => user_rst,
      main_txdma_ram_rd_en_o   => user_txdma_ram_rd_en,
      main_txdma_ram_rd_addr_o => user_txdma_ram_rd_addr,
      main_txdma_ram_rd_data_i => user_txdma_ram_rd_data,
      main_txdma_ptr_i         => user_txdma_ptr,
      main_txdma_enable_i      => user_txdma_enable,
      main_txdma_clear_o       => user_txdma_clear,
      main_rxdma_ram_wr_en_o   => user_rxdma_ram_wr_en,
      main_rxdma_ram_wr_addr_o => user_rxdma_ram_wr_addr,
      main_rxdma_ram_wr_data_o => user_rxdma_ram_wr_data,
      main_rxdma_ptr_i         => user_rxdma_ptr,
      main_rxdma_enable_i      => user_rxdma_enable,
      main_rxdma_clear_o       => user_rxdma_clear,
      main_rxdma_pending_o     => user_rxdma_pending,
      --
      eth_clk_i               => eth_clk,
      eth_rxcnt_good_o        => user_rxcnt_good,
      eth_rxcnt_error_o       => user_rxcnt_error,
      eth_rxcnt_crc_bad_o     => user_rxcnt_crc_bad,
      eth_rxcnt_overflow_o    => user_rxcnt_overflow,
      --
      eth_txd_o               => eth_txd,
      eth_txen_o              => eth_txen,
      eth_rxd_i               => eth_rxd,
      eth_rxerr_i             => '0',
      eth_crsdv_i             => eth_crsdv,
      eth_intn_i              => '0',
      eth_mdio_io             => open,
      eth_mdc_o               => open,
      eth_rstn_o              => eth_rstn,
      eth_refclk_o            => eth_refclk
   );
   

   --------------------
   -- Main test program
   --------------------

   proc_test : process
      
      procedure send_frame(first : integer; length : integer; offset : integer) is
      begin
         sim_ram_in <= (others => 'X');
         sim_ram_in(8*offset + 15 downto 8*offset + 0) <= to_std_logic_vector(length, 16);
         for i in 0 to length-1 loop
            sim_ram_in(8*(i+2+offset)+7 downto 8*(i+2+offset)) <= 
               to_std_logic_vector((i+first) mod 256, 8);
         end loop;
         sim_ram_init <= '1';

         -- Wait until memory has been updated
         wait until user_clk = '1';
         sim_ram_init <= '0';
         wait until user_clk = '1';

         assert user_txdma_clear = '0';
         user_txdma_ptr    <= to_std_logic_vector(offset, 16) + X"2000";
         user_txdma_enable <= '1';
         wait until user_txdma_clear = '1';
         user_txdma_enable <= '0';
         wait until user_clk = '1';
         wait until user_clk = '1';
         assert user_txdma_clear = '0';

      end procedure send_frame;

      procedure receive_frame(first : integer; length : integer; offset : integer) is
      begin

         assert user_rxdma_clear = '0';
         user_rxdma_ptr    <= to_std_logic_vector(offset, 16) + X"2000";
         user_rxdma_enable <= '1';
         wait until user_rxdma_clear = '1';
         user_rxdma_enable <= '0';
         wait until user_clk = '1';
         wait until user_clk = '1';
         assert user_rxdma_clear = '0';

         assert sim_ram_out(8*offset + 15 downto 8*offset + 0) = to_std_logic_vector(length, 16);
         for i in 0 to length-1 loop
            assert sim_ram_out(8*(i+2+offset)+7 downto 8*(i+2+offset)) = 
               to_std_logic_vector((i+first) mod 256, 8)
               report "i=" & integer'image(i);
         end loop;
      end procedure receive_frame;

   begin
      -- Wait for reset
      user_rxdma_enable <= '0';
      user_rxdma_ptr    <= (others => '0');
      wait until eth_rstn = '1';
      wait until user_clk = '1';

      -- Clear ram
      sim_ram_in   <= (others => 'X');
      sim_ram_init <= '1';
      wait until user_clk = '1';
      sim_ram_init <= '0';
      wait until user_clk = '1';


      -----------------------------------------------
      -- Test 1 : Send a single frame
      -- Expected behaviour: Frame is received
      -----------------------------------------------

      assert user_rxdma_pending = X"00";
      send_frame(first => 32, length => 100, offset => 1000);
      receive_frame(first => 32, length => 100, offset => 600);
      assert user_rxdma_pending = X"00";

      -- Verify statistics counters
      assert user_rxcnt_good     = 1;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 0;


      -----------------------------------------------
      -- Test 2 : Send two frames
      -- Expected behaviour: Two frames are received
      -----------------------------------------------

      assert user_rxdma_pending = X"00";
      send_frame(first => 40, length => 90, offset => 800);
      send_frame(first => 50, length => 80, offset => 400);
      receive_frame(first => 40, length => 90, offset => 400);
      assert user_rxdma_pending = X"01";
      receive_frame(first => 50, length => 80, offset => 800);
      assert user_rxdma_pending = X"00";

      -- Verify statistics counters
      assert user_rxcnt_good     = 3;
      assert user_rxcnt_error    = 0;
      assert user_rxcnt_crc_bad  = 0;
      assert user_rxcnt_overflow = 0;


      -----------------------------------------------
      -- END OF TEST
      -----------------------------------------------

      report "Test completed";
      sim_test_running <= '0';
      wait;

   end process proc_test;

end structural;

