library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- This is shift

entity shift is
   port (
      alufn_i : in  std_logic_vector( 1 downto 0);
      a_i     : in  std_logic_vector(31 downto 0);
      b_i     : in  std_logic_vector( 4 downto 0);
      shift_o : out std_logic_vector(31 downto 0)
   );
end shift;

architecture Structural of shift is

   signal shiftin : std_logic_vector(31 downto 0);
   signal concat  : std_logic_vector(63 downto 0);

   signal shft    : integer range 0 to 31;

begin

   shiftin <= (others => a_i(31)) when alufn_i(1) = '1'
              else (others => '0');

   concat <= shiftin & a_i when alufn_i(0) = '1'
             else a_i & shiftin;

   shft <= conv_integer(b_i);

   shift_o <= concat(shft+31 downto shft) when alufn_i(0) = '1'
              else concat(63-shft downto 32-shft);

end Structural;

