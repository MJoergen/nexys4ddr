library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the Arithmetic Logic Unit
-- Inputs are:
-- a_i     : From the accumulator (register 'A')
-- b_i     : Operand from memory
-- sr_i    : Current value of Status Register
-- func_i  : Current ALU function (determined from instruction).
-- Output are:
-- a_o     : New value of accumulator
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

architecture Structural of alu is

   signal c : std_logic;                     -- Copy of the input carry signal
   signal a : std_logic_vector(8 downto 0);  -- New value of carry and accumulator
   signal sr : std_logic_vector(7 downto 0); -- New value of the Status Register

   -- The Status Register contains: SV-BDIZC
   constant SR_S : integer := 7;
   constant SR_V : integer := 6;
   constant SR_Z : integer := 1;
   constant SR_C : integer := 0;

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
   p_a : process (a_i, b_i, sr_i, func_i)
   begin
      a(8) <= c;  -- Default value
      case func_i is
         when "000" => -- ORA   SZ
            a(7 downto 0) <= a_i or b_i;

         when "001" => -- AND   SZ
            a(7 downto 0) <= a_i and b_i;

         when "010" => -- EOR   SZ
            a(7 downto 0) <= a_i xor b_i;

         when "011" => -- ADC   SZCV
            a <= ('0' & a_i) + ('0' & b_i) + (X"00" & c);

         when "100" => -- STA
            a(7 downto 0) <= a_i;

         when "101" => -- LDA   SZ
            a(7 downto 0) <= b_i;

         when "110" => -- CMP   SZC
            a(7 downto 0) <= a_i;

         when "111" => -- SBC   SZCV
            a <= ('0' & a_i) + ('0' & not b_i) + (X"00" & c);

         when others =>
            null;

      end case;
   end process p_a;

   -- Calculate the new Status Register
   p_sr : process (a, a_i, b_i, sr_i, func_i)
   begin
      sr <= sr_i;  -- Keep the old value as default

      case func_i is
         when "000" => -- ORA   SZ
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when "001" => -- AND   SZ
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when "010" => -- EOR   SZ
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when "011" => -- ADC   SZCV
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_V) <= not(a_i(7) xor b_i(7)) and (a_i(7) xor a(7));
            sr(SR_C) <= a(8);

         when "100" => -- STA

         when "101" => -- LDA   SZ
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));

         when "110" => -- CMP   SZC
            sr(SR_S) <= a(7);
            sr(SR_Z) <= not or_all(a(7 downto 0));
            sr(SR_C) <= a(8);

         when "111" => -- SBC   SZCV
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

end Structural;

