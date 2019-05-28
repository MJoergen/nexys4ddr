library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module pads each frame up to a minimum of 60 bytes.

entity pad is
   port (
      clk_i      : in  std_logic;
      rst_i      : in  std_logic;

      -- Ingress
      rx_valid_i : in  std_logic;
      rx_data_i  : in  std_logic_vector(60*8-1 downto 0);
      rx_last_i  : in  std_logic;
      rx_bytes_i : in  std_logic_vector(5 downto 0);

      -- Egress
      tx_valid_o : out std_logic;
      tx_data_o  : out std_logic_vector(60*8-1 downto 0);
      tx_last_o  : out std_logic;
      tx_bytes_o : out std_logic_vector(5 downto 0)
   );
end pad;

architecture Structural of pad is

   signal rx_first : std_logic;

begin

   p_first : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if rx_valid_i = '1' then
            rx_first <= rx_last_i;
         end if;

         if rst_i = '1' then
            rx_first <= '1';
         end if;
      end if;
   end process p_first;

   -- Connect output signals
   tx_valid_o <= rx_valid_i;
   tx_data_o  <= rx_data_i;
   tx_last_o  <= rx_last_i;
   tx_bytes_o <= (others => '0') when rx_valid_i = '1' and rx_last_i = '1' and rx_first = '1' else
                 rx_bytes_i;

end Structural;

