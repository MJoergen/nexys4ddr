

--------------------------------------
-- The ALU (Arithmetic Logic Unit)
--
-- The current design is completely combinatorial
-- * OR                                (2)   (0000)
-- * AND                               (2)   (0001)
-- * XOR                               (2)   (0010)
-- * Add with carry (ADC)              (2)   (0011)
-- * = B                               (2)   (0101)
-- * Compare (same as SBC?)            (2)   (0110)
-- * Subtract with borrow (SBC)        (2)   (0111)
-- * Arithmetic shift left 1 bit (ASL) (1)   (1000)
-- * Logical shift right 1 bit (LSR)   (1)   (1010)
-- * Rotate left 1 bit (ROL)           (1)   (1001)
-- * Rotate right 1 bit (ROR)          (1)   (1011)
-- * Decrement with 1                  (1)   (1110)
-- * Increment with 1                  (1)   (1111)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity alu is
   port (
      a_i    : in  std_logic_vector(7 downto 0);
      b_i    : in  std_logic_vector(7 downto 0);
      c_i    : in  std_logic;
      func_i : in  std_logic_vector(3 downto 0);
      res_o  : out std_logic_vector(7 downto 0);
      c_o    : out std_logic;
      s_o    : out std_logic;
      v_o    : out std_logic;
      z_o    : out std_logic
   );
end alu;

architecture Structural of alu is

   signal res : std_logic_vector(8 downto 0);

   signal or0  : std_logic_vector(8 downto 0);
   signal and0 : std_logic_vector(8 downto 0);
   signal xor0 : std_logic_vector(8 downto 0);
   signal adc  : std_logic_vector(8 downto 0);
   signal cmp  : std_logic_vector(8 downto 0);
   signal sbc  : std_logic_vector(8 downto 0);
   signal asl  : std_logic_vector(8 downto 0);
   signal rol0 : std_logic_vector(8 downto 0);
   signal lsr  : std_logic_vector(8 downto 0);
   signal ror0 : std_logic_vector(8 downto 0);
   signal dec  : std_logic_vector(8 downto 0);
   signal inc  : std_logic_vector(8 downto 0);
   signal a    : std_logic_vector(8 downto 0);
   signal b    : std_logic_vector(8 downto 0);

begin

   or0  <= c_i & (a_i or b_i);
   and0 <= c_i & (a_i and b_i);
   xor0 <= c_i & (a_i xor b_i);
   adc  <= ("0" & a_i) + ("0" & b_i) + (X"00" & c_i);
   sbc  <= ("0" & a_i) + ("0" & (not b_i)) + (X"00" & c_i);
   --sbc  <= ("0" & a_i) - ("0" & b_i) - (X"00" & c_i);
   a    <= '0' & a_i;
   b    <= '0' & b_i;
   cmp  <= ("0" & a_i) + ("0" & (not b_i)) + (X"00" & '1');

   asl  <= a_i & "0";
   rol0 <= a_i & c_i;
   lsr  <= a_i(0) & "0" & a_i(7 downto 1);
   ror0 <= a_i(0) & c_i & a_i(7 downto 1);
   dec  <= ("0" & a_i) - "000000001";
   inc  <= ("0" & a_i) + "000000001";

   res <= or0    when func_i = "0000" else
          and0   when func_i = "0001" else
          xor0   when func_i = "0010" else
          adc    when func_i = "0011" else
          a      when func_i = "0100" else
          b      when func_i = "0101" else
          cmp    when func_i = "0110" else
          sbc    when func_i = "0111" else
          asl    when func_i = "1000" else
          rol0   when func_i = "1001" else
          lsr    when func_i = "1010" else
          ror0   when func_i = "1011" else
          dec    when func_i = "1110" else
          inc    when func_i = "1111" else
          c_i & a_i;

   res_o <= res(7 downto 0);
   c_o <= res(8);
   s_o <= res(7);
   v_o <= (not (a_i(7) xor b_i(7))) and (a_i(7) xor res(7)) when func_i = "0011" else
          (     a_i(7) xor b_i(7) ) and (a_i(7) xor res(7));
   z_o <= '1' when res(7 downto 0) = 0 else '0';

end architecture Structural;

