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
      func_i : in  std_logic_vector(4 downto 0);
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

   constant ALU_ORA   : std_logic_vector(4 downto 0) := B"00000";
   constant ALU_AND   : std_logic_vector(4 downto 0) := B"00001";
   constant ALU_EOR   : std_logic_vector(4 downto 0) := B"00010";
   constant ALU_ADC   : std_logic_vector(4 downto 0) := B"00011";
   constant ALU_STA   : std_logic_vector(4 downto 0) := B"00100";
   constant ALU_LDA   : std_logic_vector(4 downto 0) := B"00101";
   constant ALU_CMP   : std_logic_vector(4 downto 0) := B"00110";
   constant ALU_SBC   : std_logic_vector(4 downto 0) := B"00111";

   constant ALU_ASL_A : std_logic_vector(4 downto 0) := B"01000";
   constant ALU_ROL_A : std_logic_vector(4 downto 0) := B"01001";
   constant ALU_LSR_A : std_logic_vector(4 downto 0) := B"01010";
   constant ALU_ROR_A : std_logic_vector(4 downto 0) := B"01011";
   constant ALU_BIT_A : std_logic_vector(4 downto 0) := B"01100";
   constant ALU_DEC_A : std_logic_vector(4 downto 0) := B"01110";
   constant ALU_INC_A : std_logic_vector(4 downto 0) := B"01111";
   constant ALU_LDA_A : std_logic_vector(4 downto 0) := B"01101";

   constant ALU_ASL_B : std_logic_vector(4 downto 0) := B"10000";
   constant ALU_ROL_B : std_logic_vector(4 downto 0) := B"10001";
   constant ALU_LSR_B : std_logic_vector(4 downto 0) := B"10010";
   constant ALU_ROR_B : std_logic_vector(4 downto 0) := B"10011";
   constant ALU_BIT_B : std_logic_vector(4 downto 0) := B"10100";
   constant ALU_DEC_B : std_logic_vector(4 downto 0) := B"10110";
   constant ALU_INC_B : std_logic_vector(4 downto 0) := B"10111";

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

         when ALU_ASL_A =>
            a <= a_i(7 downto 0) & '0';

         when ALU_ROL_A =>
            a <= a_i(7 downto 0) & c;

         when ALU_LSR_A =>
            a <= a_i(0) & '0' & a_i(7 downto 1);

         when ALU_ROR_A =>
            a <= a_i(0) & c & a_i(7 downto 1);

         when ALU_BIT_A =>
            tmp(7 downto 0) <= a_i and b_i;

         when ALU_DEC_A =>
            a(7 downto 0) <= a_i - 1;

         when ALU_INC_A =>
            a(7 downto 0) <= a_i + 1;

         when ALU_LDA_A =>
            null;

         when ALU_ASL_B =>
            a <= b_i(7 downto 0) & '0';

         when ALU_ROL_B =>
            a <= b_i(7 downto 0) & c;

         when ALU_LSR_B =>
            a <= b_i(0) & '0' & b_i(7 downto 1);

         when ALU_ROR_B =>
            a <= b_i(0) & c & b_i(7 downto 1);

         when ALU_BIT_B =>
            tmp(7 downto 0) <= a_i and b_i;

         when ALU_DEC_B =>
            a(7 downto 0) <= b_i - 1;

         when ALU_INC_B =>
            a(7 downto 0) <= b_i + 1;

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

         when ALU_ASL_A | ALU_ASL_B => -- ASL   SZC
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_C) <= a(8);

         when ALU_ROL_A | ALU_ROL_B => -- ROL   SZC
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_C) <= a(8);

         when ALU_LSR_A | ALU_LSR_B => -- LSR   SZC
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_C) <= a(8);

         when ALU_ROR_A | ALU_ROR_B => -- ROR   SZC
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_C) <= a(8);

         when ALU_BIT_A => -- BIT   SZV
            sr(SR_S) <= a_i(7);
            sr(SR_Z) <= not or_all(tmp(7 downto 0));
            sr(SR_V) <= a_i(6);

         when ALU_BIT_B => -- BIT   SZV
            sr(SR_S) <= b_i(7);
            sr(SR_Z) <= not or_all(tmp(7 downto 0));
            sr(SR_V) <= b_i(6);

         when ALU_DEC_A | ALU_DEC_B => -- DEC   SZ
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when ALU_INC_A | ALU_INC_B => -- INC   SZ
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when ALU_LDA_A =>
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when others =>
            null;

      end case;
   end process p_sr;

   -- Drive output signals
   a_o  <= a(7 downto 0);
   sr_o <= sr;

end structural;

