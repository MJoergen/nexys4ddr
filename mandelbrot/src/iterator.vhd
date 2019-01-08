library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library unimacro;
use unimacro.vcomponents.all;

---------------------------
-- This module iterates the Mandelbrot fractal equation
--    new_z = z^2 + c.
-- Separating real and imaginary parts this becomes the following
-- set of equations:
--    new_x = (x+y)*(x-y) + cx
--    new_y = 2*(x*y) + cy
-- Inputs to this block are: cx_i and cy_i as well as start_i.
-- start_i should be pulsed for one clock cycle.
-- cx_i and cy_i must remain constant.
-- On output, done_o will pulse high for one clock cycle, and
-- with the iteration count in cnt_o.
--
-- This module works by using a single multiplier in a pipeline fashion
-- Cycle 1 : Input to multiplier is x and y.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y).
--
-- The XC7A100T has 240 DSP slices, so up to 240 copies of this
-- iterator can potentially be instantiated.
--
-- Real numbers are represented in 2.16 fixed point two's complement
-- form, in the range -2 to 1.9. Examples
-- -2   : 20000
-- -1   : 30000
-- -0.5 : 38000
-- 0.5  : 08000
-- 1    : 10000
-- 1.5  : 18000
--
-- One must take great care to ensure correct detection and handling
-- overflow.
--
-- Example:
-- We start with the point -1+0.5i, i.e. cx = -1 and cy = 0.5
-- The expected sequence of points is then:
-- cnt |   x           |   y           | (x+y)*(x-y)   |  x*y
-- ----+---------------+---------------+---------------+--------
--  0  | 00000 ( 0)    | 00000 ( 0)    | 00000 ( 0)    | 00000 ( 0)
--  1  | 30000 (-1)    | 08000 ( 0.5)  | 0C000 ( 0.75) | 38000 (-0.5)
--  2  | 3C000 (-0.25) | 38000 (-0.5)  | 3D000 (-0.19) | 02000 ( 0.13)
--  3  | 2D000 (-1.19) | 0C000 ( 0.75) | 0D900 ( 0.85) | 31C00 (-0.89)
--  4  | 3D900 (-0.15) | 2B800 (-1.28) | 261B1 (-1.62) | 031F8 ( 0.20)


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
   signal new_x_s      : std_logic_vector(36 downto 0);
   signal new_y_half_s : std_logic_vector(36 downto 0);
   signal cnt_r        : std_logic_vector( 8 downto 0);
   signal done_r       : std_logic;

   type state_t is (IDLE_ST, ADD_ST, MULT_ST, UPDATE_ST);
   signal state_r : state_t := IDLE_ST;

   signal x2_m_y2_s  : std_logic_vector(35 downto 0);
   signal cx_s       : std_logic_vector(35 downto 0);
   signal xy_s       : std_logic_vector(35 downto 0);
   signal cy_div_2_s : std_logic_vector(35 downto 0);

   signal ovf_x36_s  : std_logic;
   signal ovf_y36_s  : std_logic;
   signal ovf_y35_s  : std_logic;
   signal ovf_y34_s  : std_logic;

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
                  ovf_x36_s <= '0';
                  ovf_y36_s <= '0';
                  ovf_y35_s <= '0';
                  ovf_y34_s <= '0';
               end if;

            when ADD_ST =>
               a_r     <= x_r + y_r;
               b_r     <= x_r - y_r;
               state_r <= MULT_ST;

               -- Check for overflow
               if ovf_x36_s = '1' or ovf_y36_s = '1' or 
                  ovf_y35_s /= ovf_y34_s
               then
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
               x_r <= new_x_s(35 downto 18);
               y_r <= new_y_half_s(35) & new_y_half_s(33 downto 18) & "0";
               a_r <= new_x_s(35 downto 18);
               b_r <= new_y_half_s(35) & new_y_half_s(33 downto 18) & "0";

               ovf_x36_s <= new_x_s(36);
               ovf_y36_s <= new_y_half_s(36);
               ovf_y35_s <= new_y_half_s(35);
               ovf_y34_s <= new_y_half_s(34);

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

   x2_m_y2_s <= product_s(35) & product_s(32 downto 0) & "00";
   cx_s      <= cx_i & "00" & X"0000";

   i_add_overflow_x : entity work.add_overflow
      generic map (
         SIZE => 36
      )
      port map (
         a_i   => x2_m_y2_s,
         b_i   => cx_s,
         r_o   => new_x_s(35 downto 0),
         ovf_o => new_x_s(36)
      ); -- i_add_overflow_x


   --------------------------
   -- Calculate (x*y) + cy/2
   --------------------------

   xy_s       <= product_d_r(35) & product_d_r(32 downto 0) & "00";
   cy_div_2_s <= cy_i(17) & cy_i & "0" & X"0000";

   i_add_overflow_y_half : entity work.add_overflow
      generic map (
         SIZE => 36
      )
      port map (
         a_i   => xy_s,
         b_i   => cy_div_2_s,
         r_o   => new_y_half_s(35 downto 0),
         ovf_o => new_y_half_s(36)
      ); -- i_add_overflow_y_half


   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt_r;
   done_o <= done_r;

end architecture rtl;

