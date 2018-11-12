library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module generates Ethernet traffic.

entity phy_sim is
   port (
      sim_tx_data_i  : in  std_logic_vector(1600*8-1 downto 0);
      sim_tx_len_i   : in  std_logic_vector(  15 downto 0);
      sim_tx_start_i : in  std_logic;
      sim_tx_done_o  : out std_logic;
      --
      sim_rx_data_o  : out std_logic_vector(1600*8-1 downto 0);
      sim_rx_done_o  : out std_logic;
      --
      eth_refclk_i : in  std_logic;
      eth_rstn_i   : in  std_logic;
      eth_rxd_i    : in  std_logic_vector(1 downto 0);
      eth_crsdv_i  : in  std_logic;
      eth_txd_o    : out std_logic_vector(1 downto 0);
      eth_txen_o   : out std_logic
   );
end entity phy_sim;

architecture simulation of phy_sim is

   signal user_rx_valid : std_logic;
   signal user_rx_eof   : std_logic;
   signal user_rx_data  : std_logic_vector(7 downto 0);
   signal user_rx_error : std_logic_vector(1 downto 0);

   signal sim_rx_data : std_logic_vector(1600*8-1 downto 0);
   signal sim_rx_done : std_logic;

   signal user_tx_empty : std_logic;
   signal user_tx_rden  : std_logic;
   signal user_tx_data  : std_logic_vector(7 downto 0);
   signal user_tx_eof   : std_logic;

   signal sim_tx_done : std_logic;

   signal rst : std_logic;

begin

   rst <= not eth_rstn_i;

   -- Instantiate Rx
   inst_rmii_rx : entity work.rmii_rx
   port map (
      clk_i        => eth_refclk_i,
      rst_i        => rst,
      user_valid_o => user_rx_valid,
      user_eof_o   => user_rx_eof,
      user_data_o  => user_rx_data,
      user_error_o => user_rx_error,
      phy_rxd_i    => eth_rxd_i,
      phy_rxerr_i  => '0',
      phy_crsdv_i  => eth_crsdv_i,
      phy_intn_i   => '0'
   );

   sim_rx_proc : process (eth_refclk_i)
      variable pos_v : integer;
   begin
      if rising_edge(eth_refclk_i) then
         sim_rx_done <= '0';

         if user_rx_valid = '1' then
            sim_rx_data(pos_v*8+7 downto pos_v*8) <= user_rx_data;
            pos_v := pos_v + 1;
            if user_rx_eof = '1' then
               sim_rx_done <= '1';
               pos_v := 0;
            end if;
         end if;

         if rst = '1' then
            pos_v := 0;
         end if;
      end if;

   end process sim_rx_proc;

   sim_rx_data_o <= sim_rx_data;
   sim_rx_done_o <= sim_rx_done;

   -- Instantiate Tx
   inst_rmii_tx : entity work.rmii_tx
   port map (
      clk_i        => eth_refclk_i,
      rst_i        => rst,
      user_empty_i => user_tx_empty,
      user_rden_o  => user_tx_rden,
      user_data_i  => user_tx_data,
      user_eof_i   => user_tx_eof,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o
   );

   sim_tx_proc : process
   begin
      user_tx_empty <= '1';
      user_tx_data  <= (others => '0');
      user_tx_eof   <= '0';
      sim_tx_done <= '1';

      wait until sim_tx_start_i = '1';
      sim_tx_done <= '0';
      user_tx_empty <= '0';

      byte_loop : for i in 0 to to_integer(sim_tx_len_i)-1 loop
         user_tx_data <= sim_tx_data_i(8*i+7 downto 8*i);
         if i=to_integer(sim_tx_len_i)-1 then
            user_tx_eof <= '1';
         end if;

         wait until user_tx_rden = '1';
      end loop byte_loop;
   end process sim_tx_proc;

   sim_tx_done_o <= sim_tx_done;

end simulation;

