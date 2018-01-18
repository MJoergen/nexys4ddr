library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module takes an input signal, and if this input value is unchanged for
-- a specified number of clock cycles, then it will be copied to the output.

entity debounce is

   generic (
              G_COUNT_START : integer := 250000     -- At 25 MHz this is approx 10 ms
           );
   port (
           clk_i : in  std_logic;
           sig_i : in  std_logic;
           sig_o : out std_logic
        );

end entity debounce;

architecture Structural of debounce is

   signal last_s    : std_logic := '0';
   signal counter_s : integer range 0 to G_COUNT_START := 0;

begin

   p_last : process (clk_i)
   begin
      if rising_edge(clk_i) then
         last_s <= sig_i;
      end if;
   end process p_last;


   p_count : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if counter_s /= 0 then
            counter_s <= counter_s - 1;
         end if;

         if sig_i /= last_s then
            counter_s <= G_COUNT_START;
         end if;
      end if;
   end process p_count;

  
   p_out : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if counter_s = 0 then
            sig_o <= last_s;
         end if;
      end if;
   end process p_out;

end architecture Structural;

