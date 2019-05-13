library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity tb_arp is
end tb_arp;

architecture simulation of tb_arp is

   -- Signals connected to DUT.
   signal clk       : std_logic;
   signal rst       : std_logic;
   signal req_valid : std_logic;
   signal req_sof   : std_logic;
   signal req_eof   : std_logic;
   signal req_data  : std_logic_vector(7 downto 0);
   signal rsp_valid : std_logic;
   signal rsp_sof   : std_logic;
   signal rsp_eof   : std_logic;
   signal rsp_data  : std_logic_vector(7 downto 0);



   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx_start : std_logic;
   signal sim_tx_done  : std_logic;
   signal sim_tx_len   : std_logic_vector(15 downto 0);
   signal sim_tx_data  : std_logic_vector(64*8-1 downto 0);

   -- Signals for reception of the Ethernet frames.
   signal sim_rx_len   : std_logic_vector(15 downto 0);
   signal sim_rx_data  : std_logic_vector(64*8-1 downto 0);
   signal sim_rx_done  : std_logic;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

begin

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   proc_clk : process
   begin
      clk <= '1', '0' after 10 ns;
      wait for 20 ns;                  -- 50 MHz
      if test_running = '0' then
         wait;
      end if;
   end process proc_clk;

   proc_rst : process
   begin
      rst <= '1', '0' after 200 ns;
      wait;
   end process proc_rst;


   ---------------------------------
   -- Instantiate traffic generator
   ---------------------------------

   inst_sim_req : entity work.sim_tx
   port map (
      clk_i       => clk,

      sim_start_i => sim_tx_start,
      sim_data_i  => sim_tx_data,
      sim_len_i   => sim_tx_len,
      sim_done_o  => sim_tx_done,

      tx_data_o   => req_data,
      tx_sof_o    => req_sof,
      tx_eof_o    => req_eof,
      tx_valid_o  => req_valid
   ); -- inst_sim_req


--   --------------------
--   -- Instantiate the DUT
--   --------------------
--
--   inst_arp : entity work.arp
--   port map (
--      clk_i        => clk,
--      rst_i        => rst,
--      rx_valid_i   => req_valid,
--      rx_sof_i     => req_sof,
--      rx_eof_i     => req_eof,
--      rx_data_i    => req_data,
--      tx_valid_o   => rsp_valid,
--      tx_sof_o     => rsp_sof,
--      tx_eof_o     => rsp_eof,
--      tx_data_o    => rsp_data
--   ); -- inst_arp

   p_delay : process (clk)
   begin
      if rising_edge(clk) then
         rsp_valid <= req_valid;
         rsp_sof   <= req_sof;
         rsp_eof   <= req_eof;
         rsp_data  <= req_data;
      end if;
   end process p_delay;

   ---------------------------------
   -- Instantiate traffic receiver
   ---------------------------------

   inst_sim_rsp : entity work.sim_rx
   port map (
      clk_i       => clk,

      rx_data_i   => rsp_data,
      rx_sof_i    => rsp_sof,
      rx_eof_i    => rsp_eof,
      rx_valid_i  => rsp_valid,

      sim_data_o  => sim_rx_data,
      sim_len_o   => sim_rx_len,
      sim_done_o  => sim_rx_done
   ); -- inst_sim_rsp


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
      for i in 16 to 63 loop
         sim_tx_data(8*i+7 downto 8*i) <= (others => 'X');
      end loop;
      sim_tx_len   <= X"0010";
      sim_tx_start <= '1';
      wait until sim_tx_done = '1';
      sim_tx_start <= '0';

      wait until sim_rx_done = '1';
      -- Validate received frame
      assert sim_rx_len  = sim_tx_len;
      assert sim_rx_data(16*8-1 downto 0) = sim_tx_data(16*8-1 downto 0);

      -- Send another frame (32 bytes)
      for i in 0 to 31 loop
         sim_tx_data(8*i+7 downto 8*i) <= to_std_logic_vector(i+22, 8);
      end loop;
      for i in 32 to 63 loop
         sim_tx_data(8*i+7 downto 8*i) <= (others => 'X');
      end loop;
      sim_tx_len   <= X"0020";
      sim_tx_start <= '1';
      wait until sim_tx_done = '1';
      sim_tx_start <= '0';

      wait until sim_rx_done = '1';
      -- Validate received frame
      assert sim_rx_len  = sim_tx_len;
      assert sim_rx_data(32*8-1 downto 0) = sim_tx_data(32*8-1 downto 0);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

