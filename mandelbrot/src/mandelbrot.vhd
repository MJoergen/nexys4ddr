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
--    new_y = (2x)*y + cy
-- Inputs to this block are: cx_i and cy_i as well as start_i.
-- start_i should be pulsed for one clock cycle.
-- cx_i and cy_i must remain constant throughout the calculation.
--
-- It does it by using a single multiplier in a pipeline fashion
-- Cycle 1 : Input to multiplier is (2x) and y.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y).
--
-- Real numbers are represented in 2.16 fixed point two's complement
-- form, in the range -2 to 1.9. Examples
-- -2   : 20000
-- -1   : 30000
-- -0.5 : 38000
-- 0.5  : 08000
-- 1    : 10000


entity mandelbrot is
   port (
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      start_i : in  std_logic;
      cx_i    : in  std_logic_vector(17 downto 0);
      cy_i    : in  std_logic_vector(17 downto 0);
      x_o     : out std_logic_vector(17 downto 0);
      y_o     : out std_logic_vector(17 downto 0);
      cnt_o   : out std_logic_vector( 9 downto 0);
      done_o  : out std_logic
   );
end entity mandelbrot;

architecture rtl of mandelbrot is

   signal x         : std_logic_vector(17 downto 0);
   signal y         : std_logic_vector(17 downto 0);
   signal sum       : std_logic_vector(17 downto 0);
   signal diff      : std_logic_vector(17 downto 0);
   signal a         : std_logic_vector(17 downto 0);
   signal b         : std_logic_vector(17 downto 0);
   signal product   : std_logic_vector(35 downto 0);
   signal product_d : std_logic_vector(35 downto 0);
   signal cnt       : std_logic_vector( 9 downto 0);
   signal done      : std_logic;

   type state_t is (IDLE_ST, ADD_ST, MULT_ST, UPDATE_X_ST, UPDATE_Y_ST);
   signal state : state_t := IDLE_ST;

begin

   p_state : process (clk_i)
   begin
      if rising_edge(clk_i) then

         done <= '0';

         case state is
            when IDLE_ST =>
               if start_i = '1' then
                  cnt   <= to_std_logic_vector(0, 10);
                  state <= ADD_ST;
               end if;

            when ADD_ST =>
               state <= MULT_ST;

            when MULT_ST =>
               state <= UPDATE_X_ST;

            when UPDATE_X_ST =>
               state <= UPDATE_Y_ST;
               
            when UPDATE_Y_ST =>
               if x(17) = '1' or y(17) = '1' then
                  done  <= '1';
                  state <= IDLE_ST;
               else
                  cnt   <= cnt + 1;
                  state <= ADD_ST;
               end if;

            when others => null;
         end case;

         if rst_i = '1' then
            state <= IDLE_ST;
         end if;
      end if;
   end process p_state;


   p_sum_diff : process (clk_i)
   begin
      if rising_edge(clk_i) then
         sum  <= x + y;
         diff <= x - y;
      end if;
   end process p_sum_diff;


   a <= (x(16 downto 0) & '0') when state = ADD_ST else
        sum;

   b <= y when state = ADD_ST else
        diff;

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
      P   => product, -- Output
      A   => a,       -- Input
      B   => b        -- Input
   ); -- i_mult

   p_product_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         product_d <= product;
      end if;
   end process p_product_d;

   p_xy : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if state = UPDATE_Y_ST then
            y <= product_d(35 downto 18) + cy_i;
         end if;

         if state = UPDATE_X_ST then
            x <= product(35 downto 18) + cx_i;
         end if;

         if rst_i = '1' or start_i = '1' then
            x <= to_std_logic_vector(0, 18);
            y <= to_std_logic_vector(0, 18);
         end if;
      end if;
   end process p_xy;


   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt;
   done_o <= done;
   x_o    <= x;
   y_o    <= y;

end architecture rtl;

