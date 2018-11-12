library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity lo is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      lo_sel_i : in  std_logic;
      data_i   : in  std_logic_vector(7 downto 0);

      lo_o     : out std_logic_vector(7 downto 0)
   );
end entity lo;

architecture structural of lo is

   -- Address Lo register
   signal lo : std_logic_vector(7 downto 0);
   
begin

   -- 'Lo' register
   lo_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if lo_sel_i = '1' then
               lo <= data_i;
            end if;
         end if;
      end if;
   end process lo_proc;

   -- Drive output signals
   lo_o <= lo;

end architecture structural;

