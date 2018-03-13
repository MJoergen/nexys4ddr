library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module performs a "debounce" of the incoming signal.

entity debounce is

   generic (
              G_COUNT_MAX : integer := 100000 -- @ 100 MHz this is 1 millisecond.
           );
   port (
           clk_i : in  std_logic;
           in_i  : in  std_logic;
           out_o : out std_logic
        );

end entity debounce;

architecture Structural of debounce is

   signal counter : integer range 0 to G_COUNT_MAX := 0;
   signal stable  : std_logic := '0';
   signal in_d    : std_logic := '0';

begin

   -- Store previous value
   p_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         in_d <= in_i;
      end if;
   end process p_delay;

   -- Count down while input is stable
   p_counter : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if counter > 0 then
            counter <= counter - 1;
         end if;

         -- Restart counter if any transitions on the input
         if in_d /= in_i then
            counter <= G_COUNT_MAX;
         end if;
      end if;
   end process p_counter;

   -- Store output when input is stable
   p_stable : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if counter = 0 then
            stable <= in_d;
         end if;
      end if;
   end process p_stable;

   out_o <= stable;

end architecture Structural;

