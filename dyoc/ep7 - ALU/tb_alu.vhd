library ieee;
use ieee.std_logic_1164.all;
use std.textio.all;

-- This is the testbench for the ALU

entity tb_alu is
end tb_alu;

architecture Structural of tb_alu is

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

   constant tests : t_tests := (
      -- Quick test of each function
      ALU_ORA & X"35" & X"26" & X"00" & X"37" & X"00",
      ALU_AND & X"35" & X"26" & X"00" & X"24" & X"00",
      ALU_EOR & X"35" & X"26" & X"00" & X"13" & X"00",
      ALU_ADC & X"35" & X"26" & X"00" & X"5B" & X"00",
      ALU_STA & X"35" & X"26" & X"00" & X"35" & X"00",
      ALU_LDA & X"35" & X"26" & X"00" & X"26" & X"00",
      ALU_CMP & X"35" & X"26" & X"00" & X"35" & X"00",
      ALU_SBC & X"35" & X"26" & X"00" & X"0E" & X"01",

      -- Test of Zero and Sign (and carry unchanged)
      ALU_LDA & X"35" & X"00" & X"00" & X"00" & X"02",
      ALU_LDA & X"35" & X"00" & X"01" & X"00" & X"03",
      ALU_LDA & X"35" & X"80" & X"00" & X"80" & X"80",
      ALU_LDA & X"35" & X"80" & X"01" & X"80" & X"81",

      -- Test of ADC (carry)
      ALU_ADC & X"35" & X"26" & X"01" & X"5C" & X"00",
      ALU_ADC & X"35" & X"E6" & X"00" & X"1B" & X"01",
      ALU_ADC & X"35" & X"E6" & X"01" & X"1C" & X"01",

      -- Test of SBC (carry)
      ALU_SBC & X"35" & X"26" & X"01" & X"0F" & X"01",
      ALU_SBC & X"35" & X"E6" & X"00" & X"4E" & X"00",
      ALU_SBC & X"35" & X"E6" & X"01" & X"4F" & X"00"
   );

   signal i : integer := 0;   -- Index into array of tests

begin

   process
   begin
      i <= i+1 after 10 ns;
      wait for 10 ns;

      assert a_exp  = a_out  report "Received A:  " & to_hstring(a_out)  & ", expected " & to_hstring(a_exp)  severity note;
      assert sr_exp = sr_out report "Received SR: " & to_hstring(sr_out) & ", expected " & to_hstring(sr_exp) severity note;

      if i = tests'length-1 then
         wait;
      end if;
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

