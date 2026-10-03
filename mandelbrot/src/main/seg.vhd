library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This module drives the 8-digit 7-segment display on the Nexys 4 DDR board.
-- The digits share the segment signals, so they are shown one at a time
-- (multiplexed). Each digit is shown for 2^(G_REFRESH_BITS-3) clock cycles, so
-- all 8 digits are refreshed once every 2^G_REFRESH_BITS clock cycles. With
-- the default value of 17 and the MAIN clock this is 0.70 ms, i.e. 1.4 kHz.
--
-- digits_i holds one BCD digit for each 4 bits, the rightmost digit (AN0) in
-- bits 3 downto 0. A digit is switched off when its bit in blank_i is set.
-- The decimal point is not used.
--
-- The segments and the anodes are both active low. seg_o(0) is segment A (CA)
-- and seg_o(6) is segment G (CG). seg_an_o(0) is the rightmost digit (AN0).
-- The outputs are registered, and change together.

entity seg is
   generic (
      G_REFRESH_BITS : natural := 17
   );
   port (
      clk_i    : in  std_logic;
      digits_i : in  std_logic_vector(31 downto 0);
      blank_i  : in  std_logic_vector( 7 downto 0);
      seg_o    : out std_logic_vector( 6 downto 0);  -- "GFEDCBA"
      seg_an_o : out std_logic_vector( 7 downto 0)
   );
end entity seg;

architecture rtl of seg is

   -- The segments for each value of a digit, active high, "GFEDCBA". Values
   -- above 9 are not used.
   type seg_table_t is array (0 to 15) of std_logic_vector(6 downto 0);
   constant C_SEG_TABLE : seg_table_t := (
      "0111111",  -- 0
      "0000110",  -- 1
      "1011011",  -- 2
      "1001111",  -- 3
      "1100110",  -- 4
      "1101101",  -- 5
      "1111101",  -- 6
      "0000111",  -- 7
      "1111111",  -- 8
      "1101111",  -- 9
      others => "0000000");

   signal refresh_cnt : std_logic_vector(G_REFRESH_BITS-1 downto 0) := (others => '0');

begin

   p_seg : process (clk_i)
      variable sel_v   : natural range 0 to 7;
      variable digit_v : std_logic_vector(3 downto 0);
   begin
      if rising_edge(clk_i) then
         refresh_cnt <= refresh_cnt + 1;

         sel_v   := to_integer(refresh_cnt(G_REFRESH_BITS-1 downto G_REFRESH_BITS-3));
         digit_v := digits_i(4*sel_v+3 downto 4*sel_v);

         seg_o    <= not C_SEG_TABLE(to_integer(digit_v));
         seg_an_o <= (others => '1');
         if blank_i(sel_v) = '0' then
            seg_an_o(sel_v) <= '0';
         end if;
      end if;
   end process p_seg;

end architecture rtl;
