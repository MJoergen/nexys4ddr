library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity sim_rx is
   port (
      clk_i       : in  std_logic;

      rx_valid_i  : in  std_logic;
      rx_sof_i    : in  std_logic;
      rx_eof_i    : in  std_logic;
      rx_data_i   : in  std_logic_vector(7 downto 0);

      sim_data_o  : out std_logic_vector(64*8-1 downto 0);
      sim_len_o   : out std_logic_vector(15 downto 0);
      sim_done_o  : out std_logic
   );
end sim_rx;

architecture simulation of sim_rx is

   signal sim_data : std_logic_vector(64*8-1 downto 0);
   signal sim_len  : std_logic_vector(15 downto 0);
   signal sim_done : std_logic;

begin

   ---------------------------
   -- Store data received
   ---------------------------

   sim_rx_proc : process
   begin
      sim_data <= (others => 'X');
      sim_len  <= (others => '0');
      sim_done <= '0';

      byte_loop : while (true) loop
         wait until clk_i = '1';
         if rx_valid_i = '1' then
            sim_data <= sim_data(63*8-1 downto 0) & rx_data_i;
            sim_len <= sim_len + 1;
            if rx_eof_i = '1' then
               sim_done <= '1';
               wait until clk_i = '1';
               exit byte_loop;
            end if;
         end if;
      end loop byte_loop;

      if rx_valid_i /= '0' then
         wait until rx_valid_i = '0';
      end if;
   end process sim_rx_proc;

   -- Connect output signals
   sim_data_o <= sim_data;
   sim_len_o  <= sim_len;
   sim_done_o <= sim_done;

end architecture simulation;

