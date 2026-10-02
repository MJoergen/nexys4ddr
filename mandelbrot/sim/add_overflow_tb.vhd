library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- This is a short self-checking testbench for add_overflow. It checks:
-- * All combinations of inputs for SIZE = 8.
-- * A few directed cases for SIZE = 36, which is the size used in the
--   iterator, including the largest and smallest values.
--
-- The expected result is calculated by adding the inputs with one extra bit.
-- The sum fits in SIZE bits if and only if the two top bits are equal.

entity add_overflow_tb is
end entity add_overflow_tb;

architecture sim of add_overflow_tb is

   constant C_SMALL : integer := 8;
   constant C_LARGE : integer := 36;

   signal small_a   : std_logic_vector(C_SMALL-1 downto 0) := (others => '0');
   signal small_b   : std_logic_vector(C_SMALL-1 downto 0) := (others => '0');
   signal small_r   : std_logic_vector(C_SMALL-1 downto 0);
   signal small_ovf : std_logic;

   signal large_a   : std_logic_vector(C_LARGE-1 downto 0) := (others => '0');
   signal large_b   : std_logic_vector(C_LARGE-1 downto 0) := (others => '0');
   signal large_r   : std_logic_vector(C_LARGE-1 downto 0);
   signal large_ovf : std_logic;

   constant C_LARGE_MAX : std_logic_vector(C_LARGE-1 downto 0) := '0' & (C_LARGE-2 downto 0 => '1');  --  2^35-1
   constant C_LARGE_MIN : std_logic_vector(C_LARGE-1 downto 0) := '1' & (C_LARGE-2 downto 0 => '0');  -- -2^35
   constant C_LARGE_ONE : std_logic_vector(C_LARGE-1 downto 0) := (0 => '1', others => '0');
   constant C_LARGE_M1  : std_logic_vector(C_LARGE-1 downto 0) := (others => '1');

begin

   i_small : entity work.add_overflow
      generic map (SIZE => C_SMALL)
      port map (a_i => small_a, b_i => small_b, r_o => small_r, ovf_o => small_ovf);

   i_large : entity work.add_overflow
      generic map (SIZE => C_LARGE)
      port map (a_i => large_a, b_i => large_b, r_o => large_r, ovf_o => large_ovf);

   p_test : process

      procedure check_large (
         a    : std_logic_vector(C_LARGE-1 downto 0);
         b    : std_logic_vector(C_LARGE-1 downto 0);
         name : string
      ) is
         variable sum : signed(C_LARGE downto 0);
      begin
         large_a <= a;
         large_b <= b;
         wait for 1 ns;
         sum := resize(signed(a), C_LARGE+1) + resize(signed(b), C_LARGE+1);
         assert large_r = std_logic_vector(sum(C_LARGE-1 downto 0))
            report "Wrong sum for " & name
            severity error;
         assert large_ovf = (sum(C_LARGE) xor sum(C_LARGE-1))
            report "Wrong overflow for " & name
            severity error;
      end procedure check_large;

      variable sum : signed(C_SMALL downto 0);

   begin
      -- All combinations of inputs for the small adder
      for a in -2**(C_SMALL-1) to 2**(C_SMALL-1)-1 loop
         for b in -2**(C_SMALL-1) to 2**(C_SMALL-1)-1 loop
            small_a <= std_logic_vector(to_signed(a, C_SMALL));
            small_b <= std_logic_vector(to_signed(b, C_SMALL));
            wait for 1 ns;
            sum := to_signed(a + b, C_SMALL+1);
            assert small_r = std_logic_vector(sum(C_SMALL-1 downto 0))
               report "Wrong sum for " & integer'image(a) & " + " & integer'image(b)
               severity error;
            assert small_ovf = (sum(C_SMALL) xor sum(C_SMALL-1))
               report "Wrong overflow for " & integer'image(a) & " + " & integer'image(b)
               severity error;
         end loop;
      end loop;

      -- Directed cases for the large adder
      check_large(C_LARGE_ONE, C_LARGE_ONE, "1 + 1");
      check_large(C_LARGE_M1,  C_LARGE_M1,  "-1 + -1");
      check_large(C_LARGE_MAX, C_LARGE_ONE, "max + 1 (overflow)");
      check_large(C_LARGE_MIN, C_LARGE_M1,  "min + -1 (overflow)");
      check_large(C_LARGE_MAX, C_LARGE_MAX, "max + max (overflow)");
      check_large(C_LARGE_MIN, C_LARGE_MIN, "min + min (overflow)");
      check_large(C_LARGE_MAX, C_LARGE_MIN, "max + min");
      check_large(C_LARGE_MAX, C_LARGE_M1,  "max + -1");
      check_large(C_LARGE_MIN, C_LARGE_ONE, "min + 1");

      report "add_overflow_tb: finished";
      std.env.finish;
   end process p_test;

end architecture sim;
