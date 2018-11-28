library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-----------------------
-- Interrupt Controller
-----------------------

entity ic is
   port (
      clk_i      : in  std_logic;

      irq_i      : in  std_logic_vector(7 downto 0);
      irq_o      : out std_logic;

      mask_i     : in  std_logic_vector(7 downto 0);
      stat_o     : out std_logic_vector(7 downto 0);
      stat_clr_i : in  std_logic
   );
end entity ic;

architecture structural of ic is

   signal irq_latch : std_logic_vector(7 downto 0) := (others => '0');

begin

   p_latch : process (clk_i)
   begin
      if rising_edge(clk_i) then
         irq_latch <= irq_latch or irq_i;

         if stat_clr_i = '1' then
            irq_latch <= (others => '0');
         end if;
      end if;
   end process p_latch;

   stat_o <= irq_latch;

   irq_o <= '1' when (irq_latch and mask_i) /= X"00" else
            '0';

end architecture structural;

