library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module generates Ethernet traffic.

entity phy_sim is
   port (
      sim_data_i   : in  std_logic_vector(1600*8-1 downto 0);
      sim_len_i    : in  std_logic_vector(  15     downto 0);
      sim_start_i  : in  std_logic;
      sim_done_o   : out std_logic;
      --
      eth_refclk_i : in  std_logic;
      eth_rstn_i   : in  std_logic;
      eth_txd_o    : out std_logic_vector(1 downto 0);
      eth_txen_o   : out std_logic
   );
end entity phy_sim;

architecture simulation of phy_sim is

   signal user_empty : std_logic;
   signal user_rden  : std_logic;
   signal user_data  : std_logic_vector(7 downto 0);
   signal user_eof   : std_logic;

   signal rst : std_logic;

begin

   rst <= not eth_rstn_i;

   -- Instantiate Tx
   inst_rmii_tx : entity work.rmii_tx
   port map (
      clk_i        => eth_refclk_i,
      rst_i        => rst,
      user_empty_i => user_empty,
      user_rden_o  => user_rden,
      user_data_i  => user_data,
      user_eof_i   => user_eof,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o
   );

   sim_tx_proc : process
   begin
      user_empty <= '1';
      user_data  <= (others => '0');
      user_eof   <= '0';
      sim_done_o <= '1';

      wait until sim_start_i = '1';
      sim_done_o <= '0';
      user_empty <= '0';

      byte_loop : for i in 0 to to_integer(sim_len_i)-1 loop
         user_data <= sim_data_i(8*i+7 downto 8*i);
         if i=to_integer(sim_len_i)-1 then
            user_eof <= '1';
         end if;

         wait until user_rden = '1';
      end loop byte_loop;

   end process sim_tx_proc;

end simulation;

