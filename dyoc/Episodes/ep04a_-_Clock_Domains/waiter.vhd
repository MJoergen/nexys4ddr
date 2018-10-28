library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity waiter is
   port (
      clk_i  : in  std_logic;
      sw_i   : in  std_logic_vector(7 downto 0);
      wait_o : out std_logic
   );
end waiter;

architecture Structural of waiter is

   -- Generate pause signal
   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal cnt : std_logic_vector(24 downto 0) := (others => '0');

begin
   
   --------------------------------------------------
   -- Generate wait signal
   --------------------------------------------------

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         cnt <= cnt + sw_i;

         wait_o <= '1';
         if (cnt + sw_i) < cnt then
            wait_o <= '0';
         end if;

      end if;
   end process;

end architecture Structural;

