library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity alu is
   port (
      a_i     : in  std_logic_vector(7 downto 0);
      b_i     : in  std_logic_vector(7 downto 0);
      c_i     : in  std_logic;
      alu_sel : in  std_logic_vector(2 downto 0);
      r_o     : out std_logic_vector(7 downto 0);
      svzc_o  : out std_logic_vector(3 downto 0)
   );
end alu;

architecture Structural of alu is

   signal r_ora : std_logic_vector(8 downto 0);
   signal r_and : std_logic_vector(8 downto 0);
   signal r_eor : std_logic_vector(8 downto 0);
   signal r_adc : std_logic_vector(8 downto 0);
   signal r_nop : std_logic_vector(8 downto 0);
   signal r_lda : std_logic_vector(8 downto 0);
   signal r_cmp : std_logic_vector(8 downto 0);
   signal r_sbc : std_logic_vector(8 downto 0);

   signal res   : std_logic_vector(8 downto 0);

   signal r_s   : std_logic;
   signal r_v   : std_logic;
   signal r_z   : std_logic;
   signal r_c   : std_logic;

begin

   r_ora <= '0' & (a_i or b_i);
   r_and <= '0' & (a_i and b_i);
   r_eor <= '0' & (a_i xor b_i);
   r_adc <= ('0' & a_i) + ('0' & b_i) + (X"00" & c_i);
   r_nop <= (others => '0');
   r_lda <= '0' & a_i;
   r_cmp <= '0' & a_i;
   r_sbc <= ('0' & a_i) + ('1' & not b_i) + (X"00" & c_i);

   res <= r_ora when alu_sel = "000" else
          r_and when alu_sel = "001" else
          r_eor when alu_sel = "010" else
          r_adc when alu_sel = "011" else
          r_nop when alu_sel = "100" else
          r_lda when alu_sel = "101" else
          r_cmp when alu_sel = "110" else
          r_sbc when alu_sel = "111";

   r_s <= res(7);
   r_v <= '0';    -- TBD
   r_z <= '1' when res = 0 else '0';
   r_c <= res(8);

   -- Drive output signals
   r_o <= res(7 downto 0);
   svzc_o <= r_s & r_v & r_z & r_c;

end Structural;

