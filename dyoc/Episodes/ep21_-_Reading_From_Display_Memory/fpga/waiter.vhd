library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity waiter is
   port (
      clk_i  : in  std_logic;
      sw_i   : in  std_logic_vector(7 downto 0);
      wait_o : out std_logic
   );
end waiter;

architecture structural of waiter is

   -- Generate pause signal
   -- 26 bits corresponds to 55Mhz / 2^26 = 1 Hz approx.
   signal cnt    : std_logic_vector(25 downto 0) := (others => '0');
   signal waiter : std_logic := '1';

begin
   
   --------------------------------------------------
   -- Generate wait signal
   --------------------------------------------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt <= cnt + sw_i;

         waiter <= not sw_i(7);
         if (cnt + sw_i) < cnt then
            waiter <= '0';
         end if;

      end if;
   end process;

   wait_o <= waiter;

end architecture structural;

