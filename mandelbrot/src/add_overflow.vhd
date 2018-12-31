library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

entity add_overflow is
   generic (
      SIZE : integer
   );
   port (
      a_i    : in  std_logic_vector(SIZE-1 downto 0);
      b_i    : in  std_logic_vector(SIZE-1 downto 0);
      r_o    : out std_logic_vector(SIZE-1 downto 0);
      ovf_o  : out std_logic
   );
end entity add_overflow;

architecture rtl of add_overflow is

begin

   r_o <= a_i + b_i;

   ovf_o <= not(a_i(SIZE-1) xor b_i(SIZE-1)) and
            (a_i(SIZE-1) xor r_o(SIZE-1));

end architecture rtl;

