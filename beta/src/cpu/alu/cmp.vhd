library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- This is a comparator

entity cmp is
   port (
      alufn_i : in  std_logic_vector( 2 downto 1);
      z_i     : in  std_logic;
      v_i     : in  std_logic;
      n_i     : in  std_logic;
      cmp_o   : out std_logic_vector(31 downto 0)
   );
end cmp;

architecture Structural of cmp is

   signal cmp0 : std_logic;

begin

   p_cmp : process (alufn_i, z_i, v_i, n_i)
   begin
      case alufn_i(2 downto 1) is
         when "01"   => cmp0 <= z_i;
         when "10"   => cmp0 <= n_i xor v_i;
         when "11"   => cmp0 <= z_i or (n_i xor v_i);
         when others => cmp0 <= '0';
      end case;
   end process p_cmp;

   cmp_o <= "0000000000000000000000000000000" & cmp0;

end Structural;

