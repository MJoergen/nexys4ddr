library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module generates framing for data to be transmitted.
-- This reads the signal 'start' and when asserted
-- generates an Ethernet frames based on 'data' and 'len'.
-- It finally asserts the 'done' signal.

entity sim_tx is
   port (
      tx_empty_o  : out std_logic;
      tx_rden_i   : in  std_logic;
      tx_data_o   : out std_logic_vector(7 downto 0);
      tx_eof_o    : out std_logic;

      -- Signals to control the generation of the Ethernet frames for transmission.
      sim_start_i : in  std_logic;
      sim_done_o  : out std_logic;
      sim_len_i   : in  std_logic_vector(15 downto 0);
      sim_data_i  : in  std_logic_vector(128*8-1 downto 0)
   );
end sim_tx;

architecture simulation of sim_tx is

   signal tx_empty : std_logic;
   signal tx_rden  : std_logic;
   signal tx_data  : std_logic_vector(7 downto 0);
   signal tx_eof   : std_logic;

   -- Signals to control the generation of the Ethernet frames for transmission.
   signal sim_done : std_logic;

begin

   -----------------------------
   -- Generate data to send
   -----------------------------

   sim_tx_proc : process
   begin
      tx_empty <= '1';
      tx_data  <= (others => '0');
      tx_eof   <= '0';
      sim_done <= '1';

      wait until sim_start_i = '1';
      sim_done <= '0';
      tx_empty <= '0';

      byte_loop : for i in 0 to to_integer(sim_len_i)-1 loop
         tx_data <= sim_data_i(8*i+7 downto 8*i);
         if i=to_integer(sim_len_i)-1 then
            tx_eof <= '1';
         end if;

         wait until tx_rden_i = '1';
      end loop byte_loop;
   end process sim_tx_proc;

   -- Connect output signals
   tx_empty_o <= tx_empty;
   tx_data_o  <= tx_data;
   tx_eof_o   <= tx_eof;
   sim_done_o <= sim_done;

end architecture simulation;

