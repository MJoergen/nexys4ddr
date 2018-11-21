library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This little helper module generates a wait signal to slow down the CPU execution, as long as bit 7 is 0.
-- The speed is controlled by the value of inc_i.
-- If bit 7 is 1, then no wait signal is generated, and the CPU runs at full speed.
-- In other words, as inc_i increases from 0 to 127, the speed of the CPU gradually increases. Values of
-- inc_i of 128 or beyond lead to full speed operation of the CPU.

entity waiter is
   port (
      clk_i  : in  std_logic; -- Approx 25 MHz

      inc_i  : in  std_logic_vector(7 downto 0);
      wait_o : out std_logic
   );
end waiter;

architecture structural of waiter is

   -- 25 bits corresponds to 25Mhz / 2^25 = 1 Hz approx.
   signal wait_cnt_r : std_logic_vector(24 downto 0) := (others => '0');
   signal wait_r     : std_logic;

begin

   p_wait_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         wait_cnt_r <= wait_cnt_r + inc_i;
      end if;
   end process p_wait_cnt;

   p_wait : process (clk_i)
   begin
      if rising_edge(clk_i) then
         -- Check for wrap-around
         if (wait_cnt_r + inc_i) < wait_cnt_r then
            wait_r <= '0';
         else
            wait_r <= not inc_i(7);
         end if;
      end if;
   end process p_wait;

   -- Drive output signal
   wait_o <= wait_r;

end architecture structural;

