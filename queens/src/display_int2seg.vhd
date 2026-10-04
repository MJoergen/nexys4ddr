library ieee;
use ieee.std_logic_1164.all;

-- Converts a number to G_DIGITS decimal digits for the 7-segment display.
-- Digit 0 is the least significant digit.

entity display_int2seg is
   generic (
      G_DIGITS : integer;
      G_BITS   : integer
   );
   port (
      int_i  : in  std_logic_vector(G_BITS-1 downto 0);
      segs_o : out std_logic_vector(7*G_DIGITS-1 downto 0);
      dp_o   : out std_logic_vector(G_DIGITS-1 downto 0)
   );
end entity display_int2seg;

architecture synthesis of display_int2seg is

   -- Number of bits needed to hold the value n.
   function num_bits(n : natural) return natural is
      variable res : natural := 1;
   begin
      while 2**res <= n loop
         res := res + 1;
      end loop;
      return res;
   end function num_bits;

   -- Number of bits going into digit d. The top digit gets the whole input,
   -- and every other digit gets a value less than 10**(d+1).
   function digit_bits(d : natural) return natural is
   begin
      if d = G_DIGITS-1 or num_bits(10**(d+1)-1) > G_BITS then
         return G_BITS;
      end if;
      return num_bits(10**(d+1)-1);
   end function digit_bits;

   -- remain(d) is the value of the digits d-1 to 0.
   type remain_vector is array(natural range <>) of std_logic_vector(G_BITS-1 downto 0);
   signal remain : remain_vector(G_DIGITS downto 0);

begin

   remain(G_DIGITS) <= int_i;

   gen_digits : for d in G_DIGITS-1 downto 0 generate
      constant C_BITS : natural := digit_bits(d);
   begin
      remain(d)(G_BITS-1 downto C_BITS) <= (others => '0');

      i_display_digit : entity work.display_digit
         generic map (
            G_INC  => 10**d,
            G_BITS => C_BITS
         )
         port map (
            value_i  => remain(d+1)(C_BITS-1 downto 0),
            remain_o => remain(d)(C_BITS-1 downto 0),
            seg_o    => segs_o(7*d+6 downto 7*d)
         );
   end generate gen_digits;

   dp_o <= (others => '0');

end architecture synthesis;
