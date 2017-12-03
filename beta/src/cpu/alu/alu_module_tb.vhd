library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu_module_tb is
end alu_module_tb;

architecture Structural of alu_module_tb is

   signal a     : std_logic_vector(31 downto 0);
   signal b     : std_logic_vector(31 downto 0);
   signal alufn : std_logic_vector( 5 downto 0);
   signal alu   : std_logic_vector(31 downto 0);

   signal z : std_logic;
   signal v : std_logic;
   signal n : std_logic;

begin

   -- Instantiate the DUT
   i_dut : entity work.alu_module
   port map (
      alufn_i => alufn,
      a_i     => a,
      b_i     => b,
      alu_o   => alu,
      z_o     => z,
      v_o     => v,
      n_o     => n
   );

   -- This is the main test
   p_main : process
   begin
      alufn <= "000000"; -- Regular add
      a     <= std_logic_vector(to_unsigned(44, 32));
      b     <= std_logic_vector(to_unsigned(33, 32));
      wait for 10 ns;

      assert alu = 77;
      assert z = '0';
      assert v = '0';
      assert n = '0';

      wait;
   end process p_main;

end Structural;

