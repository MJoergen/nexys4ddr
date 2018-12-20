library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

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


entity dispatcher is
   generic (
      G_NUM_ITERATORS : integer
   );
   port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      startx_i : in  std_logic_vector(17 downto 0);
      starty_i : in  std_logic_vector(17 downto 0);
      stepx_i  : in  std_logic_vector(17 downto 0);
      stepy_i  : in  std_logic_vector(17 downto 0)
   );
end entity dispatcher;

architecture rtl of dispatcher is

   signal active : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal start  : std_logic_vector(G_NUM_ITERATORS-1 downto 0);
   signal cx     : std_logic_vector(17 downto 0);
   signal cy     : std_logic_vector(17 downto 0);
   signal done   : std_logic_vector(G_NUM_ITERATORS-1 downto 0);

   -- This defines a type containing an array of bytes
   type cnt_t is array (0 to G_NUM_ITERATORS-1) of std_logic_vector(9 downto 0);

   signal cnt : cnt_t;

begin

   p_cx : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if start /= 0 then
            cx <= cx + stepx_i;
         end if;

         if rst_i = '1' then
            cx <= startx_i;
         end if;
      end if;
   end process p_cx;

   cy <= starty_i;   -- TBD


   p_start : process (clk_i)
   begin
      if rising_edge(clk_i) then

         start <= (others => '0');

         l_find_inactive : for i in 0 to G_NUM_ITERATORS-1 loop
            if active(i) = '0' and start(i) = '0' then
               start(i) <= '1';
               exit l_find_inactive;
            end if;
         end loop l_find_inactive;
 
         if rst_i = '1' then
            start <= (others => '0');
         end if;
      end if;
   end process p_start;


   p_active : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if rst_i = '0' then
            assert (start and done) = 0
               report "Start and Done asserted simultaneously"
                  severity error;
         end if;

         active <= (active or start) and (not done);

         if rst_i = '1' then
            active <= (others => '0');
         end if;
      end if;
   end process p_active;


   gen_iterator : for i in 0 to G_NUM_ITERATORS-1 generate
      i_iterator : entity work.iterator
         port map (
            clk_i   => clk_i,
            rst_i   => rst_i,
            start_i => start(i),
            cx_i    => cx,
            cy_i    => cy,
            cnt_o   => cnt(i),
            done_o  => done(i)
         ); -- i_iterator
      end generate gen_iterator;

end architecture rtl;

