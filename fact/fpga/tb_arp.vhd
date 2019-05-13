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
   signal exp_rx_data  : std_logic_vector(64*8-1 downto 0);

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


   --------------------
   -- Instantiate the DUT
   --------------------

   inst_arp : entity work.arp
   generic map (
      G_MAC => X"AABBCCDDEEFF",
      G_IP  => X"0A000002"
   )
   port map (
      clk_i        => clk,
      rst_i        => rst,
      rx_valid_i   => req_valid,
      rx_sof_i     => req_sof,
      rx_eof_i     => req_eof,
      rx_data_i    => req_data,
      tx_valid_o   => rsp_valid,
      tx_sof_o     => rsp_sof,
      tx_eof_o     => rsp_eof,
      tx_data_o    => rsp_data
   ); -- inst_arp


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

--- 41 : MAC_DST[47 downto 40]       (Broadcast address)
--- 40 : MAC_DST[39 downto 32]
--- 39 : MAC_DST[31 downto 24]
--- 38 : MAC_DST[23 downto 16]
--- 37 : MAC_DST[15 downto  8]
--- 36 : MAC_DST[ 7 downto  0]
--- 35 : MAC_SRC[47 downto 40]
--- 34 : MAC_SRC[39 downto 32]
--- 33 : MAC_SRC[31 downto 24]
--- 32 : MAC_SRC[23 downto 16]
--- 31 : MAC_SRC[15 downto  8]
--- 30 : MAC_SRC[ 7 downto  0]
--- 29 : TYPE_LEN[15 downto 8]  = 08 (ARP)
--- 28 : TYPE_LEN[ 7 downto 0]  = 06
---
--- 27 : HTYPE[15 downto 8] = 00     (Ethernet)
--- 26 : HTYPE[ 7 downto 0] = 01
--- 25 : PTYPE[15 downto 8] = 08     (IPv4)
--- 24 : PTYPE[ 7 downto 0] = 00
--- 23 : HLEN[ 7 downto 0] = 06
--- 22 : PLEN[ 7 downto 0] = 04
--- 21 : OPER[15 downto 8] = 00      (Request)
--- 20 : OPER[ 7 downto 0] = 01
--- 19 : SHA[47 downto 40]
--- 18 : SHA[39 downto 32]
--- 17 : SHA[31 downto 24]
--- 16 : SHA[23 downto 16]
--- 15 : SHA[15 downto  8]
--- 14 : SHA[ 7 downto  0]
--- 13 : SPA[31 downto 24]
--- 12 : SPA[23 downto 16]
--- 11 : SPA[15 downto  8]
--- 10 : SPA[ 7 downto  0]
---  9 : THA[47 downto 40]           (Ignored)
---  8 : THA[39 downto 32]
---  7 : THA[31 downto 24]
---  6 : THA[23 downto 16]
---  5 : THA[15 downto  8]
---  4 : THA[ 7 downto  0]           (Our IP address)
---  3 : TPA[31 downto 24]
---  2 : TPA[23 downto 16]
---  1 : TPA[15 downto  8]
---  0 : TPA[ 7 downto  0]
   

   main_test_proc : process
   begin
      -- Wait until reset is complete
      sim_tx_start <= '0';
      wait until rst = '0';
      wait until clk = '1';

      sim_tx_data(42*8-1 downto 0) <= X"FFFFFFFFFFFF0011223344550806" &
                                      X"0001080006040001" &
                                      X"0011223344550A000001" &
                                      X"0000000000000A000002";
      sim_tx_data(63*8-1 downto 42*8) <= (others => 'U');
      sim_tx_len   <= X"002A";
      sim_tx_start <= '1';
      wait until sim_tx_done = '1';
      sim_tx_start <= '0';

      exp_rx_data(42*8-1 downto 0) <= X"001122334455AABBCCDDEEFF0806" &
                                      X"0001080006040002" &
                                      X"AABBCCDDEEFF0A000002" &
                                      X"0011223344550A000001";
      exp_rx_data(63*8-1 downto 42*8) <= (others => 'U');

      wait until sim_rx_done = '1';
      -- Validate received frame
      assert sim_rx_len  = 42;
      assert sim_rx_data(42*8-1 downto 0) = exp_rx_data(42*8-1 downto 0);

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

