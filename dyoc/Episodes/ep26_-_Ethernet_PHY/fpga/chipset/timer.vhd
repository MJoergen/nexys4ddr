library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This helper module emulates a timer that generates an interrupt at a fixed interval.

entity timer is
   generic (
      G_TIMER_CNT : integer
   );
   port (
      clk_i : in  std_logic;  -- Approx 25 MHz
      irq_o : out std_logic
   );
end timer;

architecture structural of timer is

   constant C_TIMER_CNT : std_logic_vector(17 downto 0) := to_std_logic_vector(G_TIMER_CNT, 18);

   signal cnt_r : std_logic_vector(17 downto 0) := (others => '0');
   signal irq_r : std_logic := '0';

begin

   --------------------------------------------------
   -- Generate timer interrupt
   --------------------------------------------------

   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then

         if cnt_r = C_TIMER_CNT-1 then
            cnt_r <= (others => '0');
         else
            cnt_r <= cnt_r + 1;
         end if;
      end if;
   end process p_cnt;

   p_irq : process (clk_i)
   begin
      if rising_edge(clk_i) then
         irq_r <= '0';

         if cnt_r = C_TIMER_CNT-1 then
            irq_r <= '1'; -- Generate interrupt at wrap around.
         end if;
      end if;
   end process p_irq;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   irq_o  <= irq_r;

end architecture structural;

