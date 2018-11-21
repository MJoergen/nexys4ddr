library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the Arithmetic Logic Unit.
--
-- Inputs are:
-- a_i     : From the 'A' register
-- b_i     : Operand from memory
-- sr_i    : Current value of Status Register
-- func_i  : Current ALU function (determined from instruction).
--
-- Outputs are:
-- a_o     : New value of 'A' register
-- sr_o    : New value of Status Register

-- The Status Register contains: SV-BDIZC

entity alu is
   port (
      a_i    : in  std_logic_vector(7 downto 0);
      b_i    : in  std_logic_vector(7 downto 0);
      sr_i   : in  std_logic_vector(7 downto 0);
      func_i : in  std_logic_vector(2 downto 0);
      a_o    : out std_logic_vector(7 downto 0);
      sr_o   : out std_logic_vector(7 downto 0)
   );
end alu;

architecture structural of alu is

   signal c   : std_logic;                    -- Copy of the input carry signal
   signal a   : std_logic_vector(8 downto 0); -- New value of carry and accumulator
   signal sr  : std_logic_vector(7 downto 0); -- New value of the Status Register
   signal tmp : std_logic_vector(8 downto 0); -- Temporary value used by CMP

   -- The Status Register contains: SV-BDIZC
   constant SR_S : integer := 7;
   constant SR_V : integer := 6;
   constant SR_Z : integer := 1;
   constant SR_C : integer := 0;

   constant ALU_ORA   : std_logic_vector(2 downto 0) := B"000";
   constant ALU_AND   : std_logic_vector(2 downto 0) := B"001";
   constant ALU_EOR   : std_logic_vector(2 downto 0) := B"010";
   constant ALU_ADC   : std_logic_vector(2 downto 0) := B"011";
   constant ALU_STA   : std_logic_vector(2 downto 0) := B"100";
   constant ALU_LDA   : std_logic_vector(2 downto 0) := B"101";
   constant ALU_CMP   : std_logic_vector(2 downto 0) := B"110";
   constant ALU_SBC   : std_logic_vector(2 downto 0) := B"111";

   -- An 8-input OR gate
   function or_all(arg : std_logic_vector(7 downto 0)) return std_logic is
      variable tmp_v : std_logic;
   begin
      tmp_v := arg(0);
      for i in 1 to 7 loop
         tmp_v := tmp_v or arg(i);
      end loop;
      return tmp_v;
   end function or_all;

begin

   c <= sr_i(0);  -- Old value of carry bit

   -- Calculate the result
   p_a : process (c, a_i, b_i, sr_i, func_i)
   begin
      tmp <= (others => '0');
      a <= c & a_i;  -- Default value
      case func_i is
         when ALU_ORA =>
            a(7 downto 0) <= a_i or b_i;

         when ALU_AND =>
            a(7 downto 0) <= a_i and b_i;

         when ALU_EOR =>
            a(7 downto 0) <= a_i xor b_i;

         when ALU_ADC =>
            a <= ('0' & a_i) + ('0' & b_i) + (X"00" & c);

         when ALU_STA =>
            null;

         when ALU_LDA =>
            a(7 downto 0) <= b_i;

         when ALU_CMP =>
            tmp <= ('0' & a_i) + ('0' & not b_i) + (X"00" & '1');

         when ALU_SBC =>
            a <= ('0' & a_i) + ('0' & not b_i) + (X"00" & c);

         when others =>
            null;

      end case;
   end process p_a;

   -- Calculate the new Status Register
   p_sr : process (a, tmp, a_i, b_i, sr_i, func_i)
   begin
      sr <= sr_i;  -- Keep the old value as default

      case func_i is
         when ALU_ORA =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when ALU_AND =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when ALU_EOR =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when ALU_ADC =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_V) <= not(a_i(7) xor b_i(7)) and (a_i(7) xor a(7));
            sr(SR_C) <= a(8);

         when ALU_STA =>

         when ALU_LDA =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when ALU_CMP =>
            sr(SR_S) <= tmp(7);
            sr(SR_Z) <= not or_all(tmp(7 downto 0));
            sr(SR_C) <= tmp(8);

         when ALU_SBC =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_V) <= (a_i(7) xor b_i(7)) and (a_i(7) xor a(7));
            sr(SR_C) <= a(8);

         when others =>
            null;

      end case;
   end process p_sr;

   -- Drive output signals
   a_o  <= a(7 downto 0);
   sr_o <= sr;

end structural;

