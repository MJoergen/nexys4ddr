library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity lan8720a_tb is
end lan8720a_tb;

architecture simulation of lan8720a_tb is

   signal clk       : std_logic;
   signal rst       : std_logic;

   signal rx_valid  : std_logic;
   signal rx_sof    : std_logic;
   signal rx_eof    : std_logic;
   signal rx_data   : std_logic_vector(7 downto 0);
   signal rx_error  : std_logic_vector(1 downto 0);
   signal phy_rxd   : std_logic_vector(1 downto 0);
   signal phy_rxerr : std_logic;
   signal phy_crsdv : std_logic;
   signal phy_intn  : std_logic;

   signal tx_empty : std_logic;
   signal tx_rden  : std_logic;
   signal tx_data  : std_logic_vector(7 downto 0);
   signal tx_eof   : std_logic;
   signal tx_err   : std_logic;
   signal phy_txd  : std_logic_vector(1 downto 0);
   signal phy_txen : std_logic;

   signal start : std_logic;
   signal done  : std_logic;
   signal len   : std_logic_vector(15 downto 0);
   signal data  : std_logic_vector(128*8-1 downto 0);

begin

   -- Generate clock
   proc_clk : process
   begin
      clk <= '1', '0' after 1 ns;
      wait for 2 ns;
   end process proc_clk;

   -- Generate reset
   proc_rst : process
   begin
      rst <= '1', '0' after 20 ns;
      wait;
   end process proc_rst;

   -- Generate data for rmii_tx
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

   -- Send to Ethernet PHY
   inst_rmii_tx : entity work.rmii_tx
   port map (
      clk_i        => clk,
      rst_i        => rst,
      user_empty_i => tx_empty,
      user_rden_o  => tx_rden,
      user_data_i  => tx_data,
      user_eof_i   => tx_eof,
      user_err_o   => tx_err,
      eth_txd_o    => phy_txd,
      eth_txen_o   => phy_txen
   );

   -- Loopback
   phy_rxd   <= phy_txd;
   phy_crsdv <= phy_txen;
   phy_rxerr <= '0';
   phy_intn  <= '0';

   -- Receive from Etheret PHY
   inst_rmii_rx : entity work.rmii_rx
   port map (
      clk_i        => clk,
      rst_i        => rst,
      user_valid_o => rx_valid,
      user_sof_o   => rx_sof,
      user_eof_o   => rx_eof,
      user_data_o  => rx_data,
      user_error_o => rx_error,
      phy_rxd_i    => phy_rxd,
      phy_rxerr_i  => phy_rxerr,
      phy_crsdv_i  => phy_crsdv,
      phy_intn_i   => phy_intn
   );

   main_test_proc : process
   begin
      start <= '0';
      wait until rst = '0';
      wait until clk = '1';

      for i in 0 to 127 loop
         data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+12, 8));
      end loop;
      len   <= X"0010";
      start <= '1';
      wait until done = '1';
      start <= '0';
      wait until done = '0';

   end process main_test_proc;

end architecture simulation;

