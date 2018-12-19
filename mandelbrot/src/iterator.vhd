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
-- cx_i and cy_i are sampled when start_i is asserted.
--
-- It does it by using a single multiplier in a pipeline fashion
-- Cycle 1 : Input to multiplier is x and y.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y).
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
-- The XC7A100T has 240 DSP slices.


entity iterator is
   port (
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      start_i : in  std_logic;
      cx_i    : in  std_logic_vector(17 downto 0);
      cy_i    : in  std_logic_vector(17 downto 0);
      cnt_o   : out std_logic_vector( 9 downto 0);
      done_o  : out std_logic
   );
end entity iterator;

architecture rtl of iterator is

   signal cx_r        : std_logic_vector(17 downto 0);
   signal cy_r        : std_logic_vector(17 downto 0);
   signal x_r         : std_logic_vector(17 downto 0);
   signal y_r         : std_logic_vector(17 downto 0);
   signal sum_r       : std_logic_vector(17 downto 0);
   signal diff_r      : std_logic_vector(17 downto 0);
   signal a_s         : std_logic_vector(17 downto 0);
   signal b_s         : std_logic_vector(17 downto 0);
   signal product_s   : std_logic_vector(35 downto 0);
   signal product_d_r : std_logic_vector(35 downto 0);
   signal new_x_s     : std_logic_vector(36 downto 0);
   signal new_y_s     : std_logic_vector(36 downto 0);
   signal cnt_r       : std_logic_vector( 9 downto 0);
   signal done_r      : std_logic;

   type state_t is (IDLE_ST, ADD_ST, MULT_ST, UPDATE_ST);
   signal state_r : state_t := IDLE_ST;

begin

   p_state : process (clk_i)
   begin
      if rising_edge(clk_i) then

         done_r <= '0';

         case state_r is
            when IDLE_ST =>
               if start_i = '1' then
                  cx_r    <= cx_i;
                  cy_r    <= cy_i;
                  cnt_r   <= to_std_logic_vector(0, 10);
                  state_r <= ADD_ST;
               end if;

            when ADD_ST =>
               state_r <= MULT_ST;

            when MULT_ST =>
               state_r <= UPDATE_ST;

            when UPDATE_ST =>
               x_r     <= new_x_s(35 downto 18);
               y_r     <= new_y_s(35 downto 18);
               cnt_r   <= cnt_r + 1;
               state_r <= ADD_ST;

            when others => null;
         end case;

         if rst_i = '1' then
            state_r <= IDLE_ST;
            x_r     <= to_std_logic_vector(0, 18);
            y_r     <= to_std_logic_vector(0, 18);
            cnt_r   <= (others => '0');
         end if;
      end if;
   end process p_state;


   p_sum_diff : process (clk_i)
   begin
      if rising_edge(clk_i) then
         sum_r  <= x_r + y_r;
         diff_r <= x_r - y_r;
      end if;
   end process p_sum_diff;


   a_s <= x_r when state_r = ADD_ST else
          sum_r;

   b_s <= y_r when state_r = ADD_ST else
          diff_r;

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
      A   => a_s,       -- Input
      B   => b_s        -- Input
   ); -- i_mult

   p_product_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         product_d_r <= product_s;
      end if;
   end process p_product_d;

   new_y_s <= (product_d_r(35) & product_d_r(31 downto 0) & "000")
              + (cy_r(17) & cy_r & "00" & X"0000");

   new_x_s <= (product_s(35) & product_s(32 downto 0) & "00")
              + (cx_r(17) & cx_r & "00" & X"0000");

   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt_r;
   done_o <= done_r;

end architecture rtl;

