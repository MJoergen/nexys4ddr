library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- This is a simple self-checking testbench for the iterator. It is not
-- bit-accurate. Instead the expected iteration count is estimated using real
-- (floating point) values, and the count from the iterator must be close to
-- this. Only a few points are tested, in order to keep the simulation short.
--
-- The iterator stops when either the maximum count is reached, or when a new
-- value of x or y is outside the range that can be represented, i.e. outside
-- the range -2 <= x < 2 (and the same for y). Outside this range |z| >= 2, and
-- the iteration diverges soon after, so this is used to detect that a point is
-- not in the Mandelbrot set. The only exception is the boundary |z| = 2, e.g.
-- the point c = -2, which is in the set (z = 0, -2, 2, 2, ...), but is
-- reported as escaping, because the value 2 can not be represented.

entity iterator_tb is
end entity iterator_tb;

architecture simulation of iterator_tb is

   constant C_MAX_COUNT : integer := 100;

   -- The iterator uses fixed point numbers (with rounding errors), so the count
   -- may differ slightly from the one calculated using real numbers.
   constant C_TOLERANCE : integer := 1;

   signal clk   : std_logic;
   signal rst   : std_logic := '1';

   signal start : std_logic := '0';
   signal cx    : std_logic_vector(17 downto 0) := (others => '0');
   signal cy    : std_logic_vector(17 downto 0) := (others => '0');
   signal cnt   : std_logic_vector( 8 downto 0);
   signal done  : std_logic;

   -- Convert a real value to the 2.16 fixed point format
   function to_fixed (r : real) return std_logic_vector is
   begin
      return std_logic_vector(to_signed(integer(round(r * 65536.0)), 18));
   end function to_fixed;

   -- Convert a value in 2.16 fixed point format to real
   function to_real (v : std_logic_vector(17 downto 0)) return real is
   begin
      return real(to_integer(signed(v))) / 65536.0;
   end function to_real;

   -- Calculate the expected iteration count, using real numbers. This models
   -- the behaviour of the iterator: Count the iterations until x or y is out
   -- of range, or until the maximum count is reached.
   function expected_count (cx_r : real; cy_r : real) return integer is
      variable x : real := 0.0;
      variable y : real := 0.0;
      variable t : real;
   begin
      for n in 1 to C_MAX_COUNT-1 loop
         t := x*x - y*y + cx_r;
         y := 2.0*x*y + cy_r;
         x := t;
         if x < -2.0 or x >= 2.0 or y < -2.0 or y >= 2.0 then
            return n;
         end if;
      end loop;
      return C_MAX_COUNT;
   end function expected_count;

begin

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

      -- Run the iterator for the point (cx_r, cy_r) and compare the count with
      -- the expected value.
      procedure check (
         cx_r : real;
         cy_r : real
      ) is
         variable exp : integer;
         variable act : integer;
      begin
         wait until rising_edge(clk);
         cx    <= to_fixed(cx_r);
         cy    <= to_fixed(cy_r);
         start <= '1';
         wait until rising_edge(clk);
         start <= '0';

         -- Wait for the iterator to finish, but not forever
         wait until done = '1' for (3*C_MAX_COUNT + 20) * 10 ns;
         assert done = '1'
            report "Timeout waiting for done for c = (" & real'image(cx_r) & ", " & real'image(cy_r) & ")"
            severity error;

         wait for 1 ns;
         act := to_integer(unsigned(cnt));

         -- Use the rounded input values, so the iterator and the model
         -- calculate with the same value of c.
         exp := expected_count(to_real(to_fixed(cx_r)), to_real(to_fixed(cy_r)));

         report "c = (" & real'image(cx_r) & ", " & real'image(cy_r) & "): " &
                "count = " & integer'image(act) & ", expected = " & integer'image(exp);

         assert abs(act - exp) <= C_TOLERANCE
            report "Wrong count for c = (" & real'image(cx_r) & ", " & real'image(cy_r) & "): " &
                   "got " & integer'image(act) & ", expected " & integer'image(exp)
            severity error;
      end procedure check;

   begin
      wait until rst = '0';

      check( 0.0,   0.0);    -- In the set, so maximum count
      check(-1.0,   0.0);    -- In the set (period 2), so maximum count
      check( 1.0,   1.0);    -- Escapes immediately
      check(-2.0,   0.0);    -- In the set, but z = 2 is out of range (see ALGORITHM.md)
      check( 0.5,   0.0);    -- Escapes quickly
      check(-1.0,   0.5);    -- Escapes quickly (example from iterator.vhd)
      check( 0.3,   0.0);    -- Escapes slowly, near the edge of the set
      check(-0.75,  0.1);    -- Escapes slowly, near the edge of the set
      check(-0.1,   0.65);   -- Escapes slowly, near the edge of the set
      check(-0.17,  1.09);   -- x+y is out of range (-2 to 2) during the iteration
      check( 0.02, -1.01);   -- x-y is out of range (-2 to 2) during the iteration

      report "iterator_tb: finished";
      std.env.finish;
   end process p_test;


   -------------------
   -- Instantiate DUT
   -------------------

   i_iterator : entity work.iterator
      generic map (
         G_MAX_COUNT => C_MAX_COUNT
      )
      port map (
         clk_i   => clk,
         rst_i   => rst,
         start_i => start,
         cx_i    => cx,
         cy_i    => cy,
         cnt_o   => cnt,
         done_o  => done
      ); -- i_iterator

end architecture simulation;
