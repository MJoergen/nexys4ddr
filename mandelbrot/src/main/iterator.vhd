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
-- This module works by using a single DSP in a pipeline fashion. The DSP
-- calculates a product and adds a constant (cx or cy/2) to it, using the
-- adder in the DSP after the multiplier (the post-adder).
-- Each iteration takes three clock cycles:
-- Cycle 1 : Input to multiplier is x and y. The values x+y and x-y are
--           calculated.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y). The output of the DSP is
--           x*y + cy/2, which gives the new value of y.
-- Cycle 3 : The output of the DSP is (x+y)*(x-y) + cx, which gives the new
--           value of x.
--
-- Points in the Mandelbrot set never overflow, so without help they take the
-- maximum number of iterations. But most of them end up in a cycle: since x
-- and y have a limited number of bits, the values repeat exactly. This is
-- detected (periodicity detection, as in Brent's cycle detection): x and y are
-- saved after iterations 1, 2, 4, 8, 16, ..., and compared with the saved
-- values in each iteration. When they are equal, the values will repeat
-- forever without an overflow, so the iteration stops, and the count is
-- G_MAX_COUNT. This gives exactly the same count as without the detection.
-- The comparison is registered (match_r), so the iteration stops one
-- iteration after the match.
--
-- The multiplier is 19x18 bits (the DSP48E1 supports 25x18 bits). The product
-- is registered (in the M register of the DSP), and the constant is registered
-- too (in the C register), but the sum is not (the P register is not used).
-- The DSP is inferred by the synthesis tool, see p_dsp.
--
-- The XC7A100T has 240 DSP slices, so up to 240 copies of this
-- iterator can potentially be instantiated.
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
-- one to the 18-bit input. The choice depends only on the sign bits of x and y.
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

   signal x_r          : std_logic_vector(17 downto 0);
   signal y_r          : std_logic_vector(17 downto 0);
   signal a_r          : std_logic_vector(18 downto 0);  -- 3.16
   signal b_r          : std_logic_vector(17 downto 0);  -- 2.16
   signal c_r          : std_logic_vector(35 downto 0);  -- 4.32
   signal x_ext_s      : std_logic_vector(18 downto 0);  -- 3.16
   signal y_ext_s      : std_logic_vector(18 downto 0);  -- 3.16
   signal sum_s        : std_logic_vector(18 downto 0);  -- 3.16, x+y
   signal diff_s       : std_logic_vector(18 downto 0);  -- 3.16, x-y
   signal product_r    : std_logic_vector(36 downto 0);  -- 5.32
   signal dsp_s        : std_logic_vector(35 downto 0);  -- 4.32
   signal cnt_r        : std_logic_vector( 8 downto 0);
   signal done_r       : std_logic := '0';

   type state_t is (IDLE_ST, ADD_ST, MULT_ST, UPDATE_ST);
   signal state_r : state_t := IDLE_ST;

   signal cx_s       : std_logic_vector(35 downto 0);  -- 4.32
   signal cy_div_2_s : std_logic_vector(35 downto 0);  -- 4.32

   signal ovf_x_s    : std_logic;
   signal ovf_y_s    : std_logic;
   signal ovf_x_r    : std_logic;
   signal ovf_y_r    : std_logic;

   -- Periodicity detection
   signal sx_r       : std_logic_vector(17 downto 0);  -- Saved value of x
   signal sy_r       : std_logic_vector(17 downto 0);  -- Saved value of y
   signal match_r    : std_logic;

begin

   -- The counter cnt_r is 9 bits wide, so with a larger G_MAX_COUNT it would
   -- wrap around before it reaches G_MAX_COUNT-1.
   assert G_MAX_COUNT <= 511
      report "The iterator needs G_MAX_COUNT <= 511"
      severity failure;

   -----------------
   -- State machine
   -----------------

   p_state : process (clk_i)
   begin
      if rising_edge(clk_i) then

         case state_r is
            when IDLE_ST =>
               if start_i = '1' then
                  x_r       <= (others => '0');
                  y_r       <= (others => '0');
                  a_r       <= (others => '0');
                  b_r       <= (others => '0');
                  cnt_r     <= (others => '0');
                  state_r   <= ADD_ST;
                  done_r    <= '0';
                  ovf_x_r   <= '0';
                  ovf_y_r   <= '0';
                  match_r   <= '0';
               end if;

            when ADD_ST =>
               -- The one of x+y and x-y that may be out of range goes to the
               -- 19-bit input of the multiplier.
               if x_r(17) = y_r(17) then
                  a_r <= sum_s;
                  b_r <= diff_s(17 downto 0);
               else
                  a_r <= diff_s;
                  b_r <= sum_s(17 downto 0);
               end if;

               -- Added to x*y in the next clock cycle
               c_r <= cy_div_2_s;

               -- Periodicity detection. Here x and y are the values after
               -- cnt_r iterations. Compare them with the saved values (from an
               -- earlier iteration, so only from iteration 2), and save them
               -- if cnt_r is a power of two. The saved values are not cleared
               -- at the start, because then each bit would need a LUT.
               match_r <= '0';
               if cnt_r(8 downto 1) /= 0 and x_r = sx_r and y_r = sy_r then
                  match_r <= '1';
               end if;
               if cnt_r /= 0 and (cnt_r and (cnt_r - 1)) = 0 then
                  sx_r <= x_r;
                  sy_r <= y_r;
               end if;

               -- Check for overflow, and for a cycle found in the previous
               -- iteration
               if ovf_x_r = '1' or ovf_y_r = '1' then
                  done_r  <= '1';
                  state_r <= IDLE_ST;
               elsif match_r = '1' then
                  cnt_r   <= std_logic_vector(to_unsigned(G_MAX_COUNT, 9));
                  done_r  <= '1';
                  state_r <= IDLE_ST;
               else
                  cnt_r   <= cnt_r + 1;
                  state_r <= MULT_ST;

                  if cnt_r = G_MAX_COUNT-1 then
                     done_r  <= '1';
                     state_r <= IDLE_ST;
                  end if;
               end if;


            when MULT_ST =>
               -- The output of the DSP is x*y + cy/2, i.e. half the new value
               -- of y. The old value of y is not needed any more.
               y_r     <= dsp_s(32 downto 15);
               ovf_y_r <= ovf_y_s;

               -- Added to (x+y)*(x-y) in the next clock cycle
               c_r <= cx_s;

               state_r <= UPDATE_ST;

            when UPDATE_ST =>
               -- The output of the DSP is (x+y)*(x-y) + cx, i.e. the new
               -- value of x.
               x_r <= dsp_s(33 downto 16);
               a_r <= dsp_s(33) & dsp_s(33 downto 16);  -- Sign extended
               b_r <= y_r;

               ovf_x_r <= ovf_x_s;

               state_r <= ADD_ST;

            when others => null;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
            done_r  <= '0';
         end if;
      end if;
   end process p_state;


   x_ext_s <= x_r(17) & x_r;
   y_ext_s <= y_r(17) & y_r;
   sum_s   <= x_ext_s + y_ext_s;
   diff_s  <= x_ext_s - y_ext_s;

   cx_s       <= (35 downto 34 => cx_i(17)) & cx_i & X"0000";
   cy_div_2_s <= (35 downto 33 => cy_i(17)) & cy_i & (14 downto 0 => '0');


   --------------------------------------------
   -- The DSP: Multiplier followed by an adder
   --------------------------------------------

   -- The product is registered, and a_r, b_r, and c_r are registered too. So
   -- this is inferred as a DSP48E1 with the registers A, B, C, and M (but not
   -- P). There is no reset, because the product is only used after a_r and b_r
   -- have been set (they are cleared at the start of the iteration).
   p_dsp : process (clk_i)
   begin
      if rising_edge(clk_i) then
         product_r <= std_logic_vector(signed(a_r) * signed(b_r));
      end if;
   end process p_dsp;

   -- Both products, x*y and (x+y)*(x-y) = x*x-y*y, are between -4 and 4, so
   -- the top bit of the 5.32 product is not needed. The sum with the constant
   -- (cx or cy/2, which are between -2 and 2) is between -6 and 6, so the
   -- addition can not overflow the 4.32 format.
   dsp_s <= product_r(35 downto 0) + c_r;


   ----------------------
   -- Overflow detection
   ----------------------

   -- In UPDATE_ST: The new x is in range if the output of the DSP is between
   -- -2 and 2, i.e. if the three top bits are equal.
   ovf_x_s <= (dsp_s(35) xor dsp_s(34)) or
              (dsp_s(34) xor dsp_s(33));

   -- In MULT_ST: The new y is twice the output of the DSP. The new y is in
   -- range if the output is between -1 and 1, i.e. if the four top bits are
   -- equal.
   ovf_y_s <= (dsp_s(35) xor dsp_s(34)) or
              (dsp_s(34) xor dsp_s(33)) or
              (dsp_s(33) xor dsp_s(32));


   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt_r;
   done_o <= done_r;

end architecture rtl;
