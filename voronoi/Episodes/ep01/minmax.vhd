library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a small combinatorial block that sorts two values.
entity minmax is
   generic (
      G_SIZE : integer
   );
   port (
      a_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      b_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      min_o : out std_logic_vector(G_SIZE-1 downto 0);
      max_o : out std_logic_vector(G_SIZE-1 downto 0)
   );
end minmax;

architecture structural of minmax is

begin

   min_o <= a_i when a_i < b_i else b_i;
   max_o <= b_i when a_i < b_i else a_i;

end architecture structural;

