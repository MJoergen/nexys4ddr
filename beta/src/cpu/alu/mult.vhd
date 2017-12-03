library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- This is the multiplier unit

entity mult is
   port (
      a_i     : in  std_logic_vector(31 downto 0);
      b_i     : in  std_logic_vector(31 downto 0);
      mult_o  : out std_logic_vector(31 downto 0)
   );
end mult;

architecture Structural of mult is

   signal res : std_logic_vector(63 downto 0);

begin

   res <= a_i * b_i;

   mult_o <= res(31 downto 0);

end Structural;

