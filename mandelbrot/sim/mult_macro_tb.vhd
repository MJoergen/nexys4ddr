library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unimacro;
use unimacro.vcomponents.all;

-- This is a quick self-checking testbench for the multiplier mult_macro. It is
-- not an exhaustive test. It checks:
-- * The latency, i.e. that the product appears exactly one clock cycle after
--   the inputs.
-- * Signed multiplication, for all four combinations of signs, and for both
--   small and large values (including the extreme values -2^17 and 2^17-1).
-- * That the product is reset.

entity mult_macro_tb is
end entity mult_macro_tb;

architecture sim of mult_macro_tb is

   signal clk : std_logic;
   signal rst : std_logic;

   signal rst_override : std_logic := '0';  -- Used to test the reset input
   signal rst_mult     : std_logic;

   signal a_s : std_logic_vector(17 downto 0) := (others => '0');
   signal b_s : std_logic_vector(17 downto 0) := (others => '0');
   signal p_s : std_logic_vector(35 downto 0);

begin

   rst_mult <= rst or rst_override;

   ----------------------------
   -- Generate clock and reset
   ----------------------------

   p_clk : process
   begin
      clk <= '0', '1' after 5 ns;
      wait for 10 ns;
   end process p_clk;

   p_rst : process
   begin
      rst <= '1';
      wait for 100 ns;
      wait until clk = '1';
      rst <= '0';
      wait;
   end process p_rst;


   ----------------------------
   -- Stimulus and checking
   ----------------------------

   p_test : process

      -- Apply the inputs just after a rising clock edge. The product must not
      -- change until the next rising clock edge, and must then be the expected
      -- value, i.e. the latency is exactly one clock cycle.
      procedure check (
         a   : integer;
         b   : integer;
         exp : std_logic_vector(35 downto 0)
      ) is
         variable old_p : std_logic_vector(35 downto 0);
      begin
         wait until rising_edge(clk);
         old_p := p_s;
         a_s <= std_logic_vector(to_signed(a, 18));
         b_s <= std_logic_vector(to_signed(b, 18));

         wait for 1 ns;
         assert p_s = old_p
            report "Latency too short: " & integer'image(a) & " * " & integer'image(b) &
                   " changed the product before the clock edge"
            severity error;

         wait until rising_edge(clk);
         wait for 1 ns;
         assert p_s = exp
            report "Wrong product (or latency too long): " & integer'image(a) & " * " & integer'image(b)
            severity error;
      end procedure check;

   begin
      wait until rst = '0';

      -- Small values, all four combinations of signs
      check(    3,     5, X"00000000F");  -- +  *  +
      check(   -3,    -5, X"00000000F");  -- -  *  -
      check(    7,    -9, X"FFFFFFFC1");  -- +  *  -
      check(   -7,     9, X"FFFFFFFC1");  -- -  *  +

      -- Zero and unity
      check(    0, 12345, X"000000000");
      check(   -1,    -1, X"000000001");
      check(    1,    -1, X"FFFFFFFFF");

      -- Large values, all four combinations of signs
      check( 131071,  131071, X"3FFFC0001");  -- +  *  +  (largest positive squared)
      check(-131072, -131072, X"400000000");  -- -  *  -  (most negative squared)
      check( 131071, -131072, X"C00020000");  -- +  *  -
      check(-131072,  131071, X"C00020000");  -- -  *  +

      -- Large value times small value
      check( 131071,       1, X"00001FFFF");
      check(-131072,       1, X"FFFFE0000");

      -- Check that reset clears the product
      wait until rising_edge(clk);
      a_s <= std_logic_vector(to_signed(1234, 18));
      b_s <= std_logic_vector(to_signed(5678, 18));
      rst_override <= '1';
      wait until rising_edge(clk);
      rst_override <= '0';
      wait for 1 ns;
      assert p_s = X"000000000"
         report "Product not cleared by reset"
         severity error;

      report "mult_macro_tb: finished";
      std.env.finish;
   end process p_test;


   i_mult_macro : mult_macro
   generic map (
      DEVICE  => "7SERIES",
      LATENCY => 1,
      WIDTH_A => 18,
      WIDTH_B => 18
   )
   port map (
      CLK => clk,
      RST => rst_mult,
      CE  => '1',
      P   => p_s,    -- Output
      A   => a_s,    -- Input
      B   => b_s     -- Input
   ); -- i_mult_macro

end architecture sim;
