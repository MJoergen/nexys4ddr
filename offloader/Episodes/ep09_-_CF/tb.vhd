library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- In this package is defined the protocol offsets within an Ethernet frame,
-- i.e. the ranges R_MAC_* and R_ARP_*
use work.eth_types_package.all;

entity tb is
end tb;

architecture simulation of tb is

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
   signal eth_rst      : std_logic := '1';

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_tx       : t_sim;

   -- Output from wide2byte
   signal tx_empty     : std_logic;
   signal tx_rden      : std_logic;
   signal tx_data      : std_logic_vector(7 downto 0);
   signal tx_last      : std_logic;

   -- Signals conected to DUT
   signal eth_txd      : std_logic_vector(1 downto 0);
   signal eth_txen     : std_logic;
   signal eth_rxd      : std_logic_vector(1 downto 0);
   signal eth_rxerr    : std_logic := '0';
   signal eth_crsdv    : std_logic;
   signal eth_intn     : std_logic;
   signal eth_mdio     : std_logic;
   signal eth_mdc      : std_logic;
   signal eth_rstn     : std_logic;
   signal eth_refclk   : std_logic;   
   signal vga_hs       : std_logic;
   signal vga_vs       : std_logic;
   signal vga_col      : std_logic_vector(11 downto 0);  -- RRRRGGGGBBB

   -- Output from eth_rx
   signal rx_valid     : std_logic;
   signal rx_last      : std_logic;
   signal rx_data      : std_logic_vector(7 downto 0);
   signal rx_ok        : std_logic;

   -- Output from strip_crc
   signal st_valid     : std_logic;
   signal st_data      : std_logic_vector(7 downto 0);
   signal st_last      : std_logic;

   -- Signals for reception of the Ethernet frames.
   signal sim_rx       : t_sim;

   -- Signal to control execution of the testbench.
   signal test_running : std_logic := '1';

begin

   --------------------------------------------------
   -- Generate clock
   --------------------------------------------------

   -- Generate clock & reset
   clk_gen : process
   begin
      clk <= '1', '0' after 5 ns; -- 100 MHz
      wait for 10 ns;
   end process clk_gen;

   proc_rst : process
   begin
      rst <= '1', '0' after 200 ns;
      wait;
   end process proc_rst;

   p_eth_rst : process (eth_refclk)
   begin
      if rising_edge(eth_refclk) then
         eth_rst <= not eth_rstn;
      end if;
   end process p_eth_rst;

   --------------------------------------------------
   -- Instantiate traffic generator
   --------------------------------------------------

   i_wide2byte : entity work.wide2byte
   generic map (
      G_BYTES    => 60
   )
   port map (
      clk_i      => eth_refclk,
      rst_i      => eth_rst,
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
      eth_clk_i  => eth_refclk,
      eth_rst_i  => eth_rst,
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
   
   i_top : entity work.top
   port map (
      clk_i        => clk,
      eth_txd_o    => eth_txd,
      eth_txen_o   => eth_txen,
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => eth_rxerr,
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => eth_intn,
      eth_mdio_io  => eth_mdio,
      eth_mdc_o    => eth_mdc,
      eth_rstn_o   => eth_rstn,
      eth_refclk_o => eth_refclk,
      vga_hs_o     => vga_hs,
      vga_vs_o     => vga_vs,
      vga_col_o    => vga_col
   ); -- i_top


   --------------------------------------------------
   -- Instantiate traffic receiver
   --------------------------------------------------

   i_eth_rx : entity work.eth_rx
   port map (
      eth_clk_i   => eth_refclk,
      eth_rst_i   => eth_rst,
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
      clk_i       => eth_refclk,
      rst_i       => eth_rst,
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
      clk_i      => eth_refclk,
      rst_i      => eth_rst,
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

      -- Verify UDP processing
      procedure verify_udp(signal tx : inout t_sim;
                           signal rx : in    t_sim) is
         constant size    : integer := 32;
         variable payload : std_logic_vector(8*size-1 downto 0);
      begin

         report "Verify UDP processing, payload size is " & integer'image(size) & " bytes.";

         wait until eth_refclk = '0';

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

         payload := X"0000000000000000000000000000080b000000000000002d0000000000000022";

         tx.data(R_UDP_HDR'right-1 downto 0) <=
            payload(payload'length-1 downto payload'length-R_UDP_HDR'right);
         tx.last  <= '0';
         tx.bytes <= (others => '0');  -- Minimum frame size is 60 bytes.
         tx.valid <= '0';

         -- Wait one clock cycle to update tx.data.
         wait until eth_refclk = '1';

         -- Updated data with correct checksum
         tx.data(R_IP_CSUM)    <= not checksum(tx.data(R_IP_HDR));

         tx.valid <= '1';
         wait until eth_refclk = '1';
         tx.valid <= '0';

         tx.data <= (others => '0');

         tx.data(tx.data'length-1 downto tx.data'length-payload'length+R_UDP_HDR'right) <=
            payload(payload'length-R_UDP_HDR'right-1 downto 0);
         tx.last  <= '1';
         tx.bytes <= to_stdlogicvector(payload'length/8+42-60, 6);
         tx.valid <= '0';

         tx.valid <= '1';
         wait until eth_refclk = '1';
         tx.valid <= '0';

         wait;
      end procedure verify_udp;

   begin
      -- Wait until reset is complete
      sim_tx.valid <= '0';
      wait until rst = '0';
      wait until eth_rstn = '1';
      wait until eth_refclk = '1';

      verify_udp(sim_tx, sim_rx);
      wait for 200 ns;

      -- Stop test
      wait until clk = '1';
      report "Test completed";
      test_running <= '0';
      wait;
   end process main_test_proc;

end architecture simulation;

