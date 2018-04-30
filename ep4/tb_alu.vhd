library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This is the testbench for the ALU

entity tb is
end tb;


architecture Structural of tb is

   signal a_in   : std_logic_vector(7 downto 0);
   signal b      : std_logic_vector(7 downto 0);
   signal sr_in  : std_logic_vector(7 downto 0);
   signal func   : std_logic_vector(2 downto 0);
   signal a_out  : std_logic_vector(7 downto 0);
   signal sr_out : std_logic_vector(7 downto 0);
   signal a_exp  : std_logic_vector(7 downto 0);
   signal sr_exp : std_logic_vector(7 downto 0);

   subtype test_entry is std_logic_vector(42 downto 0);

   type t_tests is array (natural range <>) of test_entry;

   constant ALU_ORA : std_logic_vector(2 downto 0) := "000";
   constant ALU_AND : std_logic_vector(2 downto 0) := "001";
   constant ALU_EOR : std_logic_vector(2 downto 0) := "010";
   constant ALU_ADC : std_logic_vector(2 downto 0) := "011";
   constant ALU_STA : std_logic_vector(2 downto 0) := "100";
   constant ALU_LDA : std_logic_vector(2 downto 0) := "101";
   constant ALU_CMP : std_logic_vector(2 downto 0) := "110";
   constant ALU_SBC : std_logic_vector(2 downto 0) := "111";

   constant tests : t_tests :=
      (ALU_ORA & X"35" & X"26" & X"00" & X"37" & X"00",
       ALU_AND & X"35" & X"26" & X"00" & X"24" & X"00",
       ALU_EOR & X"35" & X"26" & X"00" & X"13" & X"00",
       ALU_ADC & X"35" & X"26" & X"00" & X"5B" & X"00",
       ALU_STA & X"35" & X"26" & X"00" & X"35" & X"00",
       ALU_LDA & X"35" & X"26" & X"00" & X"26" & X"00",
       ALU_CMP & X"35" & X"26" & X"00" & X"35" & X"00",
       ALU_SBC & X"35" & X"26" & X"00" & X"0E" & X"00"
   );

   signal i : integer := 0;

begin

   process
   begin
      i <= i+1 after 10 ns;
      wait for 10 ns;

      assert a_exp = a_out;
      assert sr_exp = sr_out;
   end process;

   func   <= tests(i)(42 downto 40);
   a_in   <= tests(i)(39 downto 32);
   b      <= tests(i)(31 downto 24);
   sr_in  <= tests(i)(23 downto 16);
   a_exp  <= tests(i)(15 downto 8);
   sr_exp <= tests(i)(7 downto 0);

   inst_alu : entity work.alu
   port map (
      a_i    => a_in,
      b_i    => b,
      sr_i   => sr_in,  
      func_i => func,
      a_o    => a_out,  
      sr_o   => sr_out  
   );

end Structural;

