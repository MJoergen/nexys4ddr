library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- This design follows closely that described in
-- LAB #3 of the MIT course 6.004 Computation Structures.

entity alu_module is
   port (
      alufn_i : in  std_logic_vector( 5 downto 0);
      a_i     : in  std_logic_vector(31 downto 0);
      b_i     : in  std_logic_vector(31 downto 0);
      alu_o   : out std_logic_vector(31 downto 0);
      z_o     : out std_logic;
      v_o     : out std_logic;
      n_o     : out std_logic
   );
end alu_module;

architecture Structural of alu_module is

   signal add   : std_logic_vector(31 downto 0);
   signal boole : std_logic_vector(31 downto 0);
   signal shift : std_logic_vector(31 downto 0);
   signal cmp   : std_logic_vector(31 downto 0);
   signal mult  : std_logic_vector(31 downto 0);

   signal z : std_logic;
   signal v : std_logic;
   signal n : std_logic;

begin

   i_add : entity work.add
   port map (
      alufn_i => alufn_i(0 downto 0),
      a_i     => a_i,
      b_i     => b_i,
      s_o     => add,
      z_o     => z,
      v_o     => v,
      n_o     => n
   );

   i_cmp : entity work.cmp
   port map (
      alufn_i => alufn_i(2 downto 1),
      z_i     => z,
      v_i     => v,
      n_i     => n,
      cmp_o   => cmp
   );

   i_boole : entity work.boole
   port map (
      alufn_i => alufn_i(3 downto 0),
      a_i     => a_i,
      b_i     => b_i,
      boole_o => boole
   );

   i_shift : entity work.shift
   port map (
      alufn_i => alufn_i(1 downto 0),
      a_i     => a_i,
      b_i     => b_i(4 downto 0),
      shift_o => shift
   );

   i_mult : entity work.mult
   port map (
      a_i     => a_i,
      b_i     => b_i,
      mult_o  => mult
   );


   p_mux : process (add, boole, shift, cmp, mult, alufn_i) is
   begin
      case alufn_i(5 downto 4) is
         when "00"   => alu_o <= add;
         when "01"   => alu_o <= boole;
         when "10"   => alu_o <= shift;
         when "11"   => alu_o <= cmp;
         when others => alu_o <= (others => '0');
      end case;

      if alufn_i = "000010" then
         alu_o <= mult;
      end if;
   end process p_mux;

   z_o <= z;
   v_o <= v;
   n_o <= n;

end Structural;

