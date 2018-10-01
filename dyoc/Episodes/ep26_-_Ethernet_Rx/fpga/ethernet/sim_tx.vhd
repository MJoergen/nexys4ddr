library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module generates Ethernet traffic.

entity sim_tx is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;
      data_i     : in  std_logic_vector(128*8-1 downto 0);
      len_i      : in  std_logic_vector(15 downto 0);
      start_i    : in  std_logic;
      done_o     : out std_logic;
      eth_txd_o  : out std_logic_vector(1 downto 0);
      eth_txen_o : out std_logic
   );
end entity sim_tx;

architecture simulation of sim_tx is

   signal user_empty : std_logic;
   signal user_rden  : std_logic;
   signal user_data  : std_logic_vector(7 downto 0);
   signal user_eof   : std_logic;
   signal user_err   : std_logic;

begin

   -- Instantiate Tx
   inst_rmii_tx : entity work.rmii_tx
   port map (
      clk_i        => clk_i,
      rst_i        => rst_i,
      user_empty_i => user_empty,
      user_rden_o  => user_rden,
      user_data_i  => user_data,
      user_eof_i   => user_eof,
      user_err_o   => user_err,
      eth_txd_o    => eth_txd_o,
      eth_txen_o   => eth_txen_o
   );

   sim_tx_proc : process
   begin
      user_empty <= '1';
      user_data  <= (others => '0');
      user_eof   <= '0';
      done_o     <= '1';

      wait until start_i = '1';
      done_o     <= '0';
      user_empty <= '0';

      byte_loop : for i in 0 to conv_integer(len_i)-1 loop
         user_data <= data_i(8*i+7 downto 8*i);
         if i=conv_integer(len_i)-1 then
            user_eof <= '1';
         end if;

         wait until user_rden = '1';
      end loop byte_loop;

   end process sim_tx_proc;

end simulation;

