library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity yr is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      yr_sel_i : in  std_logic;
      alu_ar_i : in  std_logic_vector(7 downto 0);

      yr_o     : out std_logic_vector(7 downto 0)
   );
end entity yr;

architecture structural of yr is

   -- 'Y' register
   signal yr : std_logic_vector(7 downto 0);

begin

   -- 'Y' register
   yr_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if yr_sel_i = '1' then
               yr <= alu_ar_i;
            end if;
         end if;
      end if;
   end process yr_proc;

   -- Drive output signal
   yr_o <= yr;

end architecture structural;

