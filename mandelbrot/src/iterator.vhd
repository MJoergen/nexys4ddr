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
-- This module works by using a single multiplier in a pipeline fashion.
-- Each iteration takes three clock cycles:
-- Cycle 1 : Input to multiplier is x and y. The values x+y and x-y are
--           calculated.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y). The product x*y is saved.
-- Cycle 3 : The new values of x and y are calculated.
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
-- Note: The values x+y and x-y, which are input to the multiplier, are only
-- 18 bits wide. They wrap around if they are outside the range -2 to 2. This
-- is not detected.
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

library unimacro;
use unimacro.vcomponents.all;

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
   signal a_r          : std_logic_vector(17 downto 0);
   signal b_r          : std_logic_vector(17 downto 0);
   signal product_s    : std_logic_vector(35 downto 0);
   signal product_d_r  : std_logic_vector(35 downto 0);
   signal new_x_s      : std_logic_vector(35 downto 0);  -- 4.32
   signal new_y_half_s : std_logic_vector(35 downto 0);  -- 4.32 (y/2)
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

begin

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
               end if;

            when ADD_ST =>
               a_r     <= x_r + y_r;
               b_r     <= x_r - y_r;

               -- Check for overflow
               if ovf_x_r = '1' or ovf_y_r = '1' then
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
               state_r <= UPDATE_ST;

            when UPDATE_ST =>
               -- The new values of x and y are in 2.16 format. The new value of
               -- y is twice the value of y/2.
               x_r <= new_x_s(33 downto 16);
               y_r <= new_y_half_s(32 downto 15);
               a_r <= new_x_s(33 downto 16);
               b_r <= new_y_half_s(32 downto 15);

               ovf_x_r <= ovf_x_s;
               ovf_y_r <= ovf_y_s;

               state_r <= ADD_ST;

            when others => null;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
            done_r  <= '0';
         end if;
      end if;
   end process p_state;


   --------------------------
   -- Instantiate multiplier
   --------------------------

   i_mult : mult_macro
      generic map (
         DEVICE  => "7SERIES",
         LATENCY => 1,
         WIDTH_A => 18,
         WIDTH_B => 18
      )
      port map (
         CLK => clk_i,
         RST => rst_i,
         CE  => '1',
         P   => product_s, -- Output
         A   => a_r,       -- Input
         B   => b_r        -- Input
      ); -- i_mult


   -----------------------------------
   -- Register output from multiplier
   -----------------------------------

   p_product_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         product_d_r <= product_s;
      end if;
   end process p_product_d;


   ------------------------------
   -- Calculate (x+y)*(x-y) + cx
   ------------------------------

   -- The product is in 4.32 format and is between -4 and 4. The sum with cx is
   -- therefore between -6 and 6, so the addition can not overflow. The new x is
   -- in range if the sum is between -2 and 2, i.e. if the three top bits are
   -- equal.
   cx_s      <= (35 downto 34 => cx_i(17)) & cx_i & X"0000";
   new_x_s   <= product_s + cx_s;
   ovf_x_s   <= (new_x_s(35) xor new_x_s(34)) or
                (new_x_s(34) xor new_x_s(33));


   --------------------------
   -- Calculate (x*y) + cy/2
   --------------------------

   -- The new y is twice this value. The new y is in range if this value is
   -- between -1 and 1, i.e. if the four top bits are equal.
   cy_div_2_s   <= (35 downto 33 => cy_i(17)) & cy_i & (14 downto 0 => '0');
   new_y_half_s <= product_d_r + cy_div_2_s;
   ovf_y_s      <= (new_y_half_s(35) xor new_y_half_s(34)) or
                   (new_y_half_s(34) xor new_y_half_s(33)) or
                   (new_y_half_s(33) xor new_y_half_s(32));


   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt_r;
   done_o <= done_r;

end architecture rtl;

