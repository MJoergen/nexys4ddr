library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity hi is
   port (
      clk_i    : in  std_logic;
      wait_i   : in  std_logic;
      hi_sel_i : in  std_logic;
      data_i   : in  std_logic_vector(7 downto 0);

      hi_o     : out std_logic_vector(7 downto 0)
   );
end entity hi;

architecture structural of hi is

   -- Address Hi register
   signal hi : std_logic_vector(7 downto 0);
   
begin

   -- 'Hi' register
   hi_proc : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if wait_i = '0' then
            if hi_sel_i = '1' then
               hi <= data_i;
            end if;
         end if;
      end if;
   end process hi_proc;

   -- Drive output signals
   hi_o <= hi;

end architecture structural;

