---------------------------
-- This module iterates the Mandelbrot fractal equation
--    new_z = z^2 + c.
-- Separating real and imaginary parts this becomes the following
-- set of equations:
--    new_x = (x+y)*(x-y) + cx
--    new_y = 2*(x*y) + cy
-- Inputs to this block are: cx_i and cy_i as well as start_i.
-- start_i should be pulsed for one clock cycle.
-- cx_i and cy_i must remain constant until the iteration is finished.
-- On output, done_o goes high when the iteration is finished, with the
-- iteration count in cnt_o. Both stay unchanged until the next start_i.
-- The count is the number of the first iteration where x or y is out of range
-- (see below), or G_MAX_COUNT if this does not happen.
--
-- This module uses two DSPs, one for each of the equations above, and
-- calculates one iteration in every clock cycle. Each DSP calculates a
-- product and adds a constant (cx or cy/2) to it, using the adder in the DSP
-- after the multiplier (the post-adder). The sums are registered in the DSPs
-- (the P registers), and these registers are the values of x and y:
-- * The first DSP calculates (x+y)*(x-y) + cx, i.e. the new value of x. The
--   values x+y and x-y are calculated in the FPGA fabric.
-- * The second DSP calculates x*y + cy/2, i.e. half the new value of y.
-- So the path from the P registers, through the adders for x+y and x-y and
-- the multiplier and the post-adder of the first DSP, back to its P register,
-- is the longest path of the iterator, and it decides the clock frequency.
-- The inputs of the multipliers are not registered, and neither is the
-- product (the A, B, and M registers are not used), because each of them
-- would add a clock cycle to each iteration. The constants cx and cy/2 are
-- registered (the C registers). The two DSPs must be placed next to each
-- other, see mandelbrot.tcl.
--
-- At the start, the P registers are cleared, i.e. x = y = 0. Then the next
-- value is calculated in every clock cycle, also after the iteration is
-- finished (the values are not used then). So a point with n iterations takes
-- n+1 clock cycles, from the start until done_o is high.
--
-- Points in the Mandelbrot set never overflow, so without help they take the
-- maximum number of iterations. But most of them end up in a cycle: since x
-- and y have a limited number of bits, the values repeat exactly. This is
-- detected (periodicity detection, as in Brent's cycle detection): x and y are
-- saved after iterations 1, 2, 4, 8, 16, ..., and compared with the saved
-- values in each iteration. When they are equal, the values will repeat
-- forever without an overflow, so the iteration stops, and the count is
-- G_MAX_COUNT. This gives exactly the same count as without the detection.
--
-- The XC7A100T (Nexys 4 DDR) has 240 DSP slices, and the XC7A200T (MEGA65)
-- has 740. Each copy of this iterator uses two of them.
--
-- Real numbers are represented in 2.16 fixed point two's complement
-- form, in the range -2 to 2 (not including 2). Examples
-- -2   : 20000
-- -1   : 30000
-- -0.5 : 38000
-- 0.5  : 08000
-- 1    : 10000
-- 1.5  : 18000
--
-- One must take great care to ensure correct detection and handling
-- overflow. The iteration stops when the new x or y is outside the range -2 to
-- 2 (not including 2). The products are calculated in 4.32 fixed point
-- (36 bits), and the range is checked on the sum of the product and the
-- offset (cx or cy/2), not on the product alone. This is necessary, because
-- the product itself can be outside the range even if the sum is not, and
-- the other way around.
--
-- The values x+y and x-y are between -4 and 4, so they need 19 bits (3.16
-- format), but the second input of the multiplier is only 18 bits wide.
-- However, at most one of them is outside the range -2 to 2: If x and y have
-- the same sign bit, then x-y is in range, and otherwise x+y is in range. So
-- the one that may be out of range is given to the 19-bit input, and the other
-- one to the 18-bit input. The choice depends only on the sign bits of x and y,
-- so each input is calculated by an adder that adds or subtracts y.
--
-- Example:
-- We start with the point -1+0.5i, i.e. cx = -1 and cy = 0.5
-- The expected sequence of points is then (all values are in 2.16 format,
-- shown in hexadecimal):
-- cnt |   x           |   y           | (x+y)*(x-y)   |  x*y
-- ----+---------------+---------------+---------------+--------
--  0  | 00000 ( 0)    | 00000 ( 0)    | 00000 ( 0)    | 00000 ( 0)
--  1  | 30000 (-1)    | 08000 ( 0.5)  | 0C000 ( 0.75) | 38000 (-0.5)
--  2  | 3C000 (-0.25) | 38000 (-0.5)  | 3D000 (-0.19) | 02000 ( 0.13)
--  3  | 2D000 (-1.19) | 0C000 ( 0.75) | 0D900 ( 0.85) | 31C00 (-0.89)
--  4  | 3D900 (-0.15) | 2B800 (-1.28) | 261B1 (-1.62) | 031F8 ( 0.20)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;
use ieee.numeric_std.all;

entity iterator is
   generic (
      G_MAX_COUNT : integer
   );
   port (
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      start_i : in  std_logic;
      cx_i    : in  std_logic_vector(17 downto 0);
      cy_i    : in  std_logic_vector(17 downto 0);
      cnt_o   : out std_logic_vector( 8 downto 0);
      done_o  : out std_logic
   );
end entity iterator;

architecture rtl of iterator is

   -- The P registers of the two DSPs, in 4.32 format: the new value of x, and
   -- half the new value of y.
   signal px_r       : std_logic_vector(35 downto 0);
   signal py_r       : std_logic_vector(35 downto 0);

   -- The current values of x and y (2.16)
   signal x_s        : std_logic_vector(17 downto 0);
   signal y_s        : std_logic_vector(17 downto 0);

   -- The inputs of the multiplier of the first DSP: a_s is x+y or x-y
   -- (3.16), and b_s is the other one (2.16). sub_s is high when a_s is x-y.
   signal sub_s      : std_logic;
   signal a_s        : std_logic_vector(18 downto 0);
   signal b_s        : std_logic_vector(17 downto 0);

   signal cx_s       : std_logic_vector(35 downto 0);  -- 4.32
   signal cy_div_2_s : std_logic_vector(35 downto 0);  -- 4.32
   signal cx_r       : std_logic_vector(35 downto 0);
   signal cy_div_2_r : std_logic_vector(35 downto 0);

   signal ovf_s      : std_logic;
   signal match_s    : std_logic;

   -- High while iterating. Then cnt_r is the number of iterations done, i.e.
   -- x_s and y_s are the values after cnt_r iterations.
   signal busy_r     : std_logic := '0';
   signal cnt_r      : std_logic_vector( 8 downto 0);
   signal done_r     : std_logic := '0';

   -- Periodicity detection
   signal sx_r       : std_logic_vector(17 downto 0);  -- Saved value of x
   signal sy_r       : std_logic_vector(17 downto 0);  -- Saved value of y

begin

   -- The counter cnt_r is 9 bits wide, so with a larger G_MAX_COUNT it would
   -- wrap around before it reaches G_MAX_COUNT-1.
   assert G_MAX_COUNT <= 511
      report "The iterator needs G_MAX_COUNT <= 511"
      severity failure;

   x_s <= px_r(33 downto 16);
   y_s <= py_r(32 downto 15);


   ---------------------------------------
   -- The inputs of the first multiplier
   ---------------------------------------

   -- The one of x+y and x-y that may be out of range goes to the 19-bit
   -- input of the multiplier: x+y when x and y have the same sign bit, and
   -- otherwise x-y. Each of the two is a single adder, which adds or
   -- subtracts y (y xor sub, plus sub), so each bit needs only one LUT.
   sub_s <= x_s(17) xor y_s(17);
   a_s   <= (x_s(17) & x_s) + ((y_s(17) & y_s) xor (18 downto 0 => sub_s)) + sub_s;
   b_s   <= x_s + (y_s xor (17 downto 0 => not sub_s)) + (not sub_s);

   cx_s       <= (35 downto 34 => cx_i(17)) & cx_i & X"0000";
   cy_div_2_s <= (35 downto 33 => cy_i(17)) & cy_i & (14 downto 0 => '0');


   ----------------------------------------------------
   -- The DSPs: Multipliers followed by an adder each
   ----------------------------------------------------

   -- These are inferred as two DSP48E1, each with the registers C and P. Both
   -- products, x*y and (x+y)*(x-y) = x*x-y*y, are between -4 and 4, so the
   -- top bit of the 5.32 product is not needed. The sum with the constant (cx
   -- or cy/2, which are between -2 and 2) is between -6 and 6, so the
   -- addition can not overflow the 4.32 format. The P registers are cleared
   -- at the start (the synchronous reset of the DSP), i.e. x = y = 0. The
   -- constants are registered (in the C registers) in every clock cycle, so
   -- they are used from the first iteration after the start.
   p_dsp : process (clk_i)
      variable px_v : std_logic_vector(36 downto 0);
      variable py_v : std_logic_vector(35 downto 0);
   begin
      if rising_edge(clk_i) then
         px_v := std_logic_vector(signed(a_s) * signed(b_s));
         py_v := std_logic_vector(signed(x_s) * signed(y_s));
         px_r <= px_v(35 downto 0) + cx_r;
         py_r <= py_v + cy_div_2_r;
         cx_r       <= cx_s;
         cy_div_2_r <= cy_div_2_s;

         if start_i = '1' then
            px_r <= (others => '0');
            py_r <= (others => '0');
         end if;
      end if;
   end process p_dsp;


   ----------------------
   -- Overflow detection
   ----------------------

   -- The new x is in range if the output of the first DSP is between -2 and
   -- 2, i.e. if the three top bits are equal. The new y is twice the output of
   -- the second DSP. It is in range if the output is between -1 and 1, i.e. if
   -- the four top bits are equal.
   ovf_s <= (px_r(35) xor px_r(34)) or
            (px_r(34) xor px_r(33)) or
            (py_r(35) xor py_r(34)) or
            (py_r(34) xor py_r(33)) or
            (py_r(33) xor py_r(32));

   -- Periodicity detection. Compare x and y with the saved values (from an
   -- earlier iteration, so only from iteration 2).
   match_s <= '1' when cnt_r(8 downto 1) /= 0 and x_s = sx_r and y_s = sy_r else '0';


   -----------------
   -- Control
   -----------------

   p_ctrl : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if busy_r = '1' then
            -- Save x and y if cnt_r is a power of two. The saved values are not
            -- cleared at the start, because then each bit would need a LUT.
            if cnt_r /= 0 and (cnt_r and (cnt_r - 1)) = 0 then
               sx_r <= x_s;
               sy_r <= y_s;
            end if;

            -- Stop on an overflow in the last iteration (the count is the
            -- number of that iteration), or when a cycle is found, or after
            -- the last iteration.
            if ovf_s = '1' then
               busy_r <= '0';
               done_r <= '1';
            elsif match_s = '1' or cnt_r = G_MAX_COUNT-1 then
               cnt_r  <= std_logic_vector(to_unsigned(G_MAX_COUNT, 9));
               busy_r <= '0';
               done_r <= '1';
            else
               cnt_r  <= cnt_r + 1;
            end if;
         end if;

         if start_i = '1' then
            cnt_r  <= (others => '0');
            busy_r <= '1';
            done_r <= '0';
         end if;

         if rst_i = '1' then
            busy_r <= '0';
            done_r <= '0';
         end if;
      end if;
   end process p_ctrl;


   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt_r;
   done_o <= done_r;

end architecture rtl;
