library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity ar is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      ar_sel_i : in  std_logic;
      data_i   : in  std_logic_vector(7 downto 0);

      ar_o     : out std_logic_vector(7 downto 0)
   );
end entity ar;

architecture structural of ar is

   -- 'A' register
   signal ar : std_logic_vector(7 downto 0);

begin

   -- 'A' register
   ar_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if ar_sel_i = '1' then
               ar <= data_i;
            end if;
         end if;
      end if;
   end process ar_proc;

   -- Drive output signal
   ar_o <= ar;

end architecture structural;

