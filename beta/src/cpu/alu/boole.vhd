library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- This is boolean logic

entity boole is
   port (
      alufn_i : in  std_logic_vector( 3 downto 0);
      a_i     : in  std_logic_vector(31 downto 0);
      b_i     : in  std_logic_vector(31 downto 0);
      boole_o : out std_logic_vector(31 downto 0)
   );
end boole;

architecture Structural of boole is

begin

   g_bit : for i in 0 to 31 generate
      boole_o(i) <= alufn_i(conv_integer(b_i(i) & a_i(i)));
   end generate g_bit;

end Structural;

