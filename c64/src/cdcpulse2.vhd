library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module sends a one-cycle pulse from one clock domain to another.

entity cdcpulse is

   port (
           -- The sender
           rx_clk_i : in  std_logic;
           rx_in_i  : in  std_logic;

           -- The receiver
           tx_clk_i : in  std_logic;
           tx_out_o : out std_logic
        );

end entity cdcpulse;

architecture Structural of cdcpulse is

   signal rx_level_s    : std_logic := '0';
   signal tx_level_s    : std_logic := '0';
   signal tx_level_d_s  : std_logic := '0';
   signal tx_level_d2_s : std_logic := '0';

begin

   ------------------------------
   -- Convert from pulse to level
   ------------------------------

   p_rx : process (rx_clk_i)
   begin
      if rising_edge(rx_clk_i) then
         if rx_in_i = '1' then
            rx_level_s <= not rx_level_s;
         end if;
      end if;
   end process p_rx;


   --------------------
   -- Synchronize level
   --------------------

   p_tx : process (tx_clk_i)
   begin
      if rising_edge(tx_clk_i) then
         tx_level_s    <= rx_level_s;
         tx_level_d_s  <= tx_level_s;
         tx_level_d2_s <= tx_level_d_s;
      end if;
   end process p_tx;


   ------------------------------
   -- Convert from level to pulse
   ------------------------------

   tx_out_o <= tx_level_d_s xor tx_level_d2_s;

end architecture Structural;

