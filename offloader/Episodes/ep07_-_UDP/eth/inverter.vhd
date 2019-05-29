library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module is a small test module that inverts everything received.

entity inverter is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Ingress to client
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress from client
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end inverter;

architecture Structural of inverter is

begin

   tx_valid_o <= rx_valid_i;
   tx_data_o  <= not rx_data_i;
   tx_last_o  <= rx_last_i;
   tx_bytes_o <= rx_bytes_i;

end Structural;

