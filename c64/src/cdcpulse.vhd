library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module does a "closed loop" synchronization of a pulse between two
-- clock domains.  It does a full handshake in both directions, so it works for
-- any combination of clock frequencies.

entity cdcpulse is

   port (
           -- The sender
           rx_clk_i : in  std_logic;
           rx_in_i  : in  std_logic;
           rx_ack_o : out std_logic;

           -- The receiver
           tx_clk_i : in  std_logic;
           tx_out_o : out std_logic;
           tx_ack_i : in  std_logic
        );

end entity cdcpulse;

architecture Structural of cdcpulse is

   signal tx_out_s : std_logic := '0';
   signal rx_ack_s : std_logic := '0';

begin

   p_rx : process (rx_clk_i)
   begin
      if rising_edge(rx_clk_i) then

         -- Clear latch when sender has been notified and cleared the ack
         if tx_out_s = '0' then
            rx_ack_s <= '0';
         end if;

         -- Latch rising ack to the sender
         if tx_ack_i = '1' then
            rx_ack_s <= '1';
         end if;

      end if;
   end process p_rx;


   p_tx : process (tx_clk_i)
   begin
      if rising_edge(tx_clk_i) then

         -- Clear latch when receiver has been notified and cleared the source
         if rx_ack_s = '1' then
            tx_out_s <= '0';
         end if;

         -- Latch rising input to the receiver
         if rx_in_i = '1' then
            tx_out_s <= '1';
         end if;

      end if;
   end process p_tx;

   rx_ack_o <= rx_ack_s;
   tx_out_o <= tx_out_s;

end architecture Structural;

