library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity sr is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      sr_sel_i : in  std_logic;
      alu_sr_i : in  std_logic_vector(7 downto 0);

      sr_o     : out std_logic_vector(7 downto 0)
   );
end entity sr;

architecture structural of sr is

   -- Status register
   signal sr : std_logic_vector(7 downto 0);

begin

   sr_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if sr_sel_i = '1' then
               sr <= alu_sr_i;
            end if;
         end if;
      end if;
   end process sr_proc;

   -- Drive output signal
   sr_o <= sr;

end architecture structural;

