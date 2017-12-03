library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- This is an adder

entity add is
   port (
      alufn_i : in  std_logic_vector( 0 downto 0);
      a_i     : in  std_logic_vector(31 downto 0);
      b_i     : in  std_logic_vector(31 downto 0);
      s_o     : out std_logic_vector(31 downto 0);
      z_o     : out std_logic;
      v_o     : out std_logic;
      n_o     : out std_logic
   );
end add;

architecture Structural of add is

   signal xa : std_logic_vector(31 downto 0);
   signal xb : std_logic_vector(31 downto 0);
   signal s  : std_logic_vector(31 downto 0);

   signal z : std_logic;
   signal v : std_logic;
   signal n : std_logic;

begin

   -- Inputs to adder
   xa <= a_i;
   xb <= not b_i when alufn_i(0) = '1' 
         else b_i;

   -- Calculate sum
   s <= xa + xb + ("000000000000000000000000000000" & alufn_i);

   -- Calculate flags
   z <= '1' when s = 0
        else '0';

   v <= (xa(31) and xb(31) and (not s(31))) or ((not xa(31)) and (not xb(31)) and s(31));

   n <= s(31);

   -- Set outputs
   s_o <= s;
   z_o <= z;
   v_o <= v;
   n_o <= n;

end Structural;

