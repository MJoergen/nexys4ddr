library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a self-verifying testbench for the Ethernet module.

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

entity tb_eth is
end tb_eth;

architecture simulation of tb_eth is

   constant C_DUT_MAC : std_logic_vector(47 downto 0) := X"001122334455";
   constant C_DUT_IP  : std_logic_vector(31 downto 0) := X"C0A8014D";     -- 192.168.1.77
   constant C_DUT_UDP : std_logic_vector(15 downto 0) := X"1234";         -- 4660

   type t_sim is record
      valid : std_logic;
      data  : std_logic_vector(60*8-1 downto 0);
      last  : std_logic;
      bytes : std_logic_vector(5 downto 0);
   end record t_sim;

   signal clk          : std_logic;
   signal rst          : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx       : t_sim;

   -- Output from wide2byte
   signal tx_empty     : std_logic;
   signal tx_rden      : std_logic;
   signal tx_data      : std_logic_vector(7 downto 0);
   signal tx_last      : std_logic;

   -- Signals conected to DUT
   signal eth_rstn     : std_logic;
   signal eth_rxd      : std_logic_vector(1 downto 0);
   signal eth_crsdv    : std_logic;
   signal eth_txd      : std_logic_vector(1 downto 0);
   signal eth_txen     : std_logic;
   signal debug        : std_logic_vector(255 downto 0);

   -- Connected to UDP client
   signal udp_rx_valid : std_logic;
   signal udp_rx_data  : std_logic_vector(60*8-1 downto 0);
   signal udp_rx_last  : std_logic;
   signal udp_rx_bytes : std_logic_vector(5 downto 0);
   signal udp_tx_valid : std_logic;
   signal udp_tx_data  : std_logic_vector(60*8-1 downto 0);
   signal udp_tx_last  : std_logic;
   signal udp_tx_bytes : std_logic_vector(5 downto 0);

   -- Output from eth_rx
   signal rx_valid     : std_logic;
   signal rx_last      : std_logic;
   signal rx_data      : std_logic_vector(7 downto 0);
   signal rx_ok        : std_logic;

   -- Output from strip_crc
   signal st_valid  : std_logic;
   signal st_data   : std_logic_vector(7 downto 0);
   signal st_last   : std_logic;

   -- Signals for reception of the Ethernet frames.
   signal sim_rx       : t_sim;
   signal exp          : t_sim;

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
   generic map (
      G_MY_MAC => C_DUT_MAC,
      G_MY_IP  => C_DUT_IP,
      G_MY_UDP => C_DUT_UDP
   )
   port map (
      clk_i          => clk,
      rst_i          => rst,
      debug_o        => debug,
      udp_rx_valid_o => udp_rx_valid,
      udp_rx_data_o  => udp_rx_data,
      udp_rx_last_o  => udp_rx_last,
      udp_rx_bytes_o => udp_rx_bytes,
      udp_tx_valid_i => udp_tx_valid,
      udp_tx_data_i  => udp_tx_data,
      udp_tx_last_i  => udp_tx_last,
      udp_tx_bytes_i => udp_tx_bytes,
      eth_txd_o      => eth_txd,
      eth_txen_o     => eth_txen,
      eth_rxd_i      => eth_rxd,
      eth_rxerr_i    => '0',
      eth_crsdv_i    => eth_crsdv,
      eth_intn_i     => '0',
      eth_mdio_io    => open,
      eth_mdc_o      => open,
      eth_rstn_o     => eth_rstn,
      eth_refclk_o   => open
   ); -- i_eth


   --------------------------------------------------
   -- Instantiate Inverter
   --------------------------------------------------

   i_inverter : entity work.inverter
   port map (
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => udp_rx_valid,
      rx_data_i  => udp_rx_data,
      rx_last_i  => udp_rx_last,
      rx_bytes_i => udp_rx_bytes,
      --
      tx_valid_o => udp_tx_valid,
      tx_data_o  => udp_tx_data,
      tx_last_o  => udp_tx_last,
      tx_bytes_o => udp_tx_bytes
   ); -- i_inverter


   --------------------------------------------------
   -- Instantiate traffic receiver
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => clk,
      eth_rst_i   => rst,
      eth_rxd_i   => eth_txd,
      eth_rxerr_i => '0',
      eth_crsdv_i => eth_txen,
      rx_valid_o  => rx_valid,
      rx_data_o   => rx_data,
      rx_last_o   => rx_last,
      rx_ok_o     => rx_ok
   ); -- i_eth_rx

   i_strip_crc : entity work.strip_crc
   port map (
      clk_i       => clk,
      rst_i       => rst,
      rx_valid_i  => rx_valid,
      rx_data_i   => rx_data,
      rx_last_i   => rx_last,
      rx_ok_i     => rx_ok,
      out_valid_o => st_valid,
      out_data_o  => st_data,
      out_last_o  => st_last
   ); -- i_strip_crc

   i_byte2wide : entity work.byte2wide
   generic map (
      G_BYTES    => 60
   )
   port map (
      clk_i      => clk,
      rst_i      => rst,
      rx_valid_i => st_valid,
      rx_data_i  => st_data,
      rx_last_i  => st_last,
      tx_valid_o => sim_rx.valid,
      tx_data_o  => sim_rx.data,
      tx_last_o  => sim_rx.last,
      tx_bytes_o => sim_rx.bytes
   ); -- i_byte2wide


   --------------------------------------------------
   -- Main test procedure starts here
   --------------------------------------------------

   main_test_proc : process

      -- Verify ARP processing
      procedure verify_arp(signal tx : inout t_sim;
                           signal rx : in    t_sim) is
      begin

         report "Verify ARP processing.";

         -- Send one ARP request
         tx.valid <= '1';
         tx.data  <= (others => '0');
         tx.data(R_MAC_DST)  <= X"FFFFFFFFFFFF";
         tx.data(R_MAC_SRC)  <= X"66778899AABB";
         tx.data(R_MAC_TLEN) <= X"0806";
         tx.data(R_ARP_HDR)  <= X"0001080006040001";
         tx.data(R_ARP_SHA)  <= X"AABBCCDDEEFF";
         tx.data(R_ARP_SPA)  <= X"C0A80101";
         tx.data(R_ARP_THA)  <= X"000000000000";
         tx.data(R_ARP_TPA)  <= C_DUT_IP;
         tx.last  <= '1';
         tx.bytes <= (others => '0');       -- Frame size 60 bytes.
         wait until clk = '1';
         tx.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(R_MAC_DST)  <= X"66778899AABB";
         exp.data(R_MAC_SRC)  <= C_DUT_MAC;
         exp.data(R_MAC_TLEN) <= X"0806";
         exp.data(R_ARP_HDR)  <= X"0001080006040002";
         exp.data(R_ARP_SHA)  <= C_DUT_MAC;
         exp.data(R_ARP_SPA)  <= C_DUT_IP;
         exp.data(R_ARP_THA)  <= X"AABBCCDDEEFF";
         exp.data(R_ARP_TPA)  <= X"C0A80101";
         exp.last  <= '1';
         exp.bytes <= (others => '0');

         -- Verify ARP response is correct
         wait until clk = '1' and rx.valid = '1';
         wait until clk = '0';
         assert rx.data  = exp.data;
         assert rx.last  = exp.last;
         assert rx.bytes = exp.bytes;
      end procedure verify_arp;

      -- Verify ICMP processing
      procedure verify_icmp(signal tx : inout t_sim;
                            signal rx : in    t_sim) is
      begin

         report "Verify ICMP processing.";

         -- Build ICMP request
         tx.data  <= (others => '0');
         tx.data(R_MAC_DST)   <= X"001122334455";
         tx.data(R_MAC_SRC)   <= X"AABBCCDDEEFF";
         tx.data(R_MAC_TLEN)  <= X"0800";
         tx.data(R_IP_VIHL)   <= X"45";
         tx.data(R_IP_DSCP)   <= X"00";
         tx.data(R_IP_LEN)    <= X"001C";
         tx.data(R_IP_ID)     <= X"0000";
         tx.data(R_IP_FRAG)   <= X"0000";
         tx.data(R_IP_TTL)    <= X"40";
         tx.data(R_IP_PROT)   <= X"01";   -- ICMP
         tx.data(R_IP_CSUM)   <= X"0000";
         tx.data(R_IP_SRC)    <= X"C0A80101";
         tx.data(R_IP_DST)    <= C_DUT_IP;
         tx.data(R_ICMP_TC)   <= X"0800"; -- Echo request
         tx.data(R_ICMP_CSUM) <= X"0000";
         tx.data(R_ICMP_ID)   <= X"0000";
         tx.data(R_ICMP_SEQ)  <= X"1234";
         tx.last  <= '1';
         tx.bytes <= (others => '0');       -- Frame size 60 bytes.
         tx.valid <= '0';

         -- Build expected response
         exp.data  <= (others => '0');
         exp.data(R_MAC_DST)   <= X"AABBCCDDEEFF";
         exp.data(R_MAC_SRC)   <= C_DUT_MAC;
         exp.data(R_MAC_TLEN)  <= X"0800";
         exp.data(R_IP_VIHL)   <= X"45";
         exp.data(R_IP_DSCP)   <= X"00";
         exp.data(R_IP_LEN)    <= X"001C";
         exp.data(R_IP_ID)     <= X"0000";
         exp.data(R_IP_FRAG)   <= X"0000";
         exp.data(R_IP_TTL)    <= X"40";
         exp.data(R_IP_PROT)   <= X"01";   -- ICMP
         exp.data(R_IP_CSUM)   <= X"0000";
         exp.data(R_IP_SRC)    <= C_DUT_IP;
         exp.data(R_IP_DST)    <= X"C0A80101";
         exp.data(R_ICMP_TC)   <= X"0000";   -- Echo response
         exp.data(R_ICMP_CSUM) <= X"0000";
         exp.data(R_ICMP_ID)   <= X"0000";
         exp.data(R_ICMP_SEQ)  <= X"1234";
         exp.last  <= '1';
         exp.bytes <= (others => '0');
         exp.valid <= '0';

         -- Wait one clock cycle.
         wait until clk = '1';

         -- Updated data with correct checksum
         tx.data(R_IP_CSUM)    <= not checksum(tx.data(R_IP_HDR));
         tx.data(R_ICMP_CSUM)  <= not checksum(tx.data(R_ICMP_HDR));
         exp.data(R_IP_CSUM)   <= not checksum(exp.data(R_IP_HDR));
         exp.data(R_ICMP_CSUM) <= not checksum(exp.data(R_ICMP_HDR));

         tx.valid <= '1';
         wait until clk = '1';
         tx.valid <= '0';

         -- Verify ICMP response is correct
         wait until clk = '1' and rx.valid = '1';
         wait until clk = '0';
         assert rx.data  = exp.data;
         assert rx.last  = exp.last;
         assert rx.bytes = exp.bytes;
      end procedure verify_icmp;

      -- Verify UDP processing
      procedure verify_udp(signal tx : inout t_sim;
                           signal rx : in    t_sim;
                           constant size : integer) is
         variable remain : integer;                              
      begin

         report "Verify UDP processing, payload size is " & integer'image(size) & " bytes.";

         -- Build UDP request
         tx.data  <= (others => '0');
         tx.data(R_MAC_DST)   <= C_DUT_MAC;
         tx.data(R_MAC_SRC)   <= X"AABBCCDDEEFF";
         tx.data(R_MAC_TLEN)  <= X"0800";
         tx.data(R_IP_VIHL)   <= X"45";
         tx.data(R_IP_DSCP)   <= X"00";
         tx.data(R_IP_LEN)    <= to_stdlogicvector(20+8+size, 16);
         tx.data(R_IP_ID)     <= X"0000";
         tx.data(R_IP_FRAG)   <= X"0000";
         tx.data(R_IP_TTL)    <= X"40";
         tx.data(R_IP_PROT)   <= X"11";   -- UDP
         tx.data(R_IP_CSUM)   <= X"0000";
         tx.data(R_IP_SRC)    <= X"C0A80101";
         tx.data(R_IP_DST)    <= C_DUT_IP;
         tx.data(R_UDP_SRC)   <= X"4321";
         tx.data(R_UDP_DST)   <= C_DUT_UDP;
         tx.data(R_UDP_LEN)   <= to_stdlogicvector(8+size, 16);
         tx.data(R_UDP_CSUM)  <= X"0000";

         -- UDP payload
         if size <= 18 then
            for i in 0 to size-1 loop
               tx.data(R_UDP_HDR'right-1-i*8 downto R_UDP_HDR'right-8-i*8) <=
                  to_stdlogicvector(i+size, 8);
            end loop;
            tx.last  <= '1';
            tx.bytes <= (others => '0');  -- Minimum frame size is 60 bytes.
            tx.valid <= '0';
         else
            for i in 0 to 17 loop
               tx.data(R_UDP_HDR'right-1-i*8 downto R_UDP_HDR'right-8-i*8) <=
                  to_stdlogicvector(i+size, 8);
            end loop;
            tx.last  <= '0';
            tx.bytes <= (others => '0');  -- Minimum frame size is 60 bytes.
            tx.valid <= '0';
         end if;

         -- Build expected response
         exp.data  <= (others => '1');
         exp.data(R_MAC_DST)   <= X"AABBCCDDEEFF";
         exp.data(R_MAC_SRC)   <= C_DUT_MAC;
         exp.data(R_MAC_TLEN)  <= X"0800";
         exp.data(R_IP_VIHL)   <= X"45";
         exp.data(R_IP_DSCP)   <= X"00";
         exp.data(R_IP_LEN)    <= to_stdlogicvector(20+8+size, 16);
         exp.data(R_IP_ID)     <= X"0000";
         exp.data(R_IP_FRAG)   <= X"0000";
         exp.data(R_IP_TTL)    <= X"40";
         exp.data(R_IP_PROT)   <= X"11";   -- UDP
         exp.data(R_IP_CSUM)   <= X"0000";
         exp.data(R_IP_SRC)    <= C_DUT_IP;
         exp.data(R_IP_DST)    <= X"C0A80101";
         exp.data(R_UDP_SRC)   <= C_DUT_UDP;
         exp.data(R_UDP_DST)   <= X"4321";
         exp.data(R_UDP_LEN)   <= to_stdlogicvector(8+size, 16);
         exp.data(R_UDP_CSUM)  <= X"0000";

         -- UDP payload
         if size <= 18 then
            for i in 0 to size-1 loop
               exp.data(R_UDP_HDR'right-1-i*8 downto R_UDP_HDR'right-8-i*8) <=
                  not to_stdlogicvector(i+size, 8);
            end loop;
            exp.last  <= '1';
            exp.bytes <= (others => '0');  -- Minimum frame size is 60 bytes.
            exp.valid <= '0';
         else
            for i in 0 to 17 loop
               exp.data(R_UDP_HDR'right-1-i*8 downto R_UDP_HDR'right-8-i*8) <=
                  not to_stdlogicvector(i+size, 8);
            end loop;
            exp.last  <= '0';
            exp.bytes <= (others => '0');  -- Minimum frame size is 60 bytes.
            exp.valid <= '0';
         end if;

         -- Wait one clock cycle.
         wait until clk = '1';

         -- Updated data with correct checksum
         tx.data(R_IP_CSUM)    <= not checksum(tx.data(R_IP_HDR));
         exp.data(R_IP_CSUM)   <= not checksum(exp.data(R_IP_HDR));

         tx.valid <= '1';
         wait until clk = '1';
         tx.valid <= '0';

         if size > 18 then
            tx.data <= (others => '0');
            for i in 18 to size-1 loop
               tx.data(78*8-1-i*8 downto 78*8-8-i*8) <=
                  to_stdlogicvector(i+size, 8);
            end loop;
            tx.last  <= '1';
            tx.bytes <= to_stdlogicvector(size-18, 6);
            tx.valid <= '1';
            wait until clk = '1';
            tx.valid <= '0';
         end if;


         -- Verify UDP response is correct
         wait until clk = '1' and rx.valid = '1';
         wait until clk = '0';
         assert rx.data  = exp.data;
         assert rx.last  = exp.last;
         assert rx.bytes = exp.bytes;

         if size > 18 then
            exp.data <= (others => '1');
            for i in 18 to size-1 loop
               exp.data(78*8-1-i*8 downto 78*8-8-i*8) <=
                  not to_stdlogicvector(i+size, 8);
            end loop;
            exp.last  <= '1';
            exp.bytes <= to_stdlogicvector(size-18, 6);
            exp.valid <= '0';

            if rx.valid = '0' then
               wait until clk = '1' and rx.valid = '1';
               wait until clk = '0';
            end if;
            assert rx.data  = exp.data;
            assert rx.last  = exp.last;
            assert rx.bytes = exp.bytes;
         end if;

      end procedure verify_udp;

   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until rst = '0';
      wait until eth_rstn = '1';
      wait until clk = '1';

      verify_arp(sim_tx, sim_rx);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_icmp(sim_tx, sim_rx);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 1);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 2);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 17);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 19);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 20);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 21);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 42);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 59);
      wait for 100 ns; -- Wait a little while to ease debugging                                               
      verify_udp(sim_tx, sim_rx, 60);
      wait for 100 ns; -- Wait a little while to ease debugging                                               

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

