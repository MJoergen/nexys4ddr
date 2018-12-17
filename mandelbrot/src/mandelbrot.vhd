library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

--library unisim;
--use unisim.vcomponents.all;
--
--library unimacro;
--use unimacro.vcomponents.all;

---------------------------
-- This module performs the following calculations:
-- new_x = (x+y)*(x-y) + cx
-- new_y = (2x)*y + cy
--
-- It does it by using a single multiplier in a pipeline fashion
-- Cycle 1 : Input to multiplier is (2x) and y.
-- Cycle 2 : Input to multiplier is (x+y) and (x-y).

entity mandelbrot is
   port (
      clk_i  : in  std_logic;
      rst_i  : in  std_logic;
      cx_i   : in  std_logic_vector(17 downto 0);
      cy_i   : in  std_logic_vector(17 downto 0);
      cnt_o  : out std_logic_vector( 9 downto 0);
      done_o : out std_logic
   );
end entity mandelbrot;

architecture rtl of mandelbrot is

   signal x         : std_logic_vector(17 downto 0);
   signal y         : std_logic_vector(17 downto 0);
   signal state     : std_logic_vector( 1 downto 0);
   signal sum       : std_logic_vector(17 downto 0);
   signal diff      : std_logic_vector(17 downto 0);
   signal a         : std_logic_vector(17 downto 0);
   signal b         : std_logic_vector(17 downto 0);
   signal product   : std_logic_vector(35 downto 0);
   signal product_d : std_logic_vector(35 downto 0);
   signal cnt       : std_logic_vector( 9 downto 0);
   signal done      : std_logic;

begin

   p_state : process (clk_i)
   begin
      if rising_edge(clk_i) then
         state <= state + 1;

         if rst_i = '1' then
            state <= "00";
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


   a <= (x(16 downto 0) & '0') when state = 0 else
        sum;

   b <= y when state = 0 else
        diff;

--   i_mult : mult_macro
--   generic map (
--      DEVICE  => "7SERIES",
--      LATENCY => 1,
--      WIDTH_A => 18,
--      WIDTH_B => 18
--   )
--   port map (
--      CLK => clk_i,
--      RST => rst_i,
--      CE  => '1',
--      P   => product, -- Output
--      A   => a,       -- Input
--      B   => b        -- Input
--   ); -- i_mult

   process (clk_i)
   begin
      if rising_edge(clk_i) then
         product <= a*b;
      end if;
   end process;

   p_product_d : process (clk_i)
   begin
      if rising_edge(clk_i) then
         product_d <= product;
      end if;
   end process p_product_d;

   p_xy : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if state = 2 then
            y <= product_d(35 downto 18) + cy_i;
         end if;

         if state = 3 then
            x <= product(35 downto 18) + cx_i;
         end if;

         if rst_i = '1' then
            x <= to_std_logic_vector(0, 18);
            y <= to_std_logic_vector(0, 18);
         end if;
      end if;
   end process p_xy;

   p_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if state = 0 then
            cnt <= cnt + 1;
         end if;

         if rst_i = '1' then
            cnt <= to_std_logic_vector(0, 10);
         end if;
      end if;
   end process p_cnt;

   p_done : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if x(17) = '1' or y(17) = '1' then
            done <= '1';
         end if;

         if rst_i = '1' then
            done <= '0';
         end if;
      end if;
   end process p_done;


   --------------------------
   -- Connect output signals
   --------------------------

   cnt_o  <= cnt;
   done_o <= done;

end architecture rtl;

