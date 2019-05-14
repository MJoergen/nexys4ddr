library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- A simple counter to generate a test signal. This is only used temporarily.

entity debug is
   port (
      clk_i : in  std_logic;
      hex_o : out std_logic_vector(255 downto 0)
   );
end debug;

architecture structural of debug is

   signal hex : std_logic_vector(255 downto 0) := (others => '0');

begin
   
   --------------------------------------------------
   -- Generate test signal
   --------------------------------------------------

   p_hex : process (clk_i)
   begin
      if rising_edge(clk_i) then
         hex <= hex + 1;
      end if;
   end process p_hex;


   -- Drive output signals
   hex_o <= hex;

end architecture structural;

