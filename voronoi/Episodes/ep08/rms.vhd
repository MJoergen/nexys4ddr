library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a small combinatorial block that computes an
-- approximation to the RMS of two values, i.e.
-- rms = sqrt(x^2 + y^2).
-- The approximation boils down to (assuming 0 < x < y)
-- choosing the maximum of the following lines:
-- line0 : 128*rms =        128*y
-- line1 : 128*rms = 16*x + 127*y
-- line2 : 128*rms = 32*x + 124*y
-- line3 : 128*rms = 47*x + 119*y
-- line4 : 128*rms = 62*x + 112*y
-- line5 : 128*rms = 76*x + 103*y
-- line6 : 128*rms = 89*x +  92*y
--
-- In general, all lines are of the form 128*rms = a*x + b*y, where
-- the constants a and b satisfy (approximately) a^2+b^2 = 128^2.
--
-- The output is stored in fixed point with G_RESOLUTION fractional bits.
-- Since the constants a and b are scaled by 128, G_RESOLUTION must be 7.
--
-- The calculation is pipelined with a latency of 3 clock cycles.

entity rms is
   generic (
      G_RESOLUTION : integer;
      G_SIZE       : integer
   );
   port (
      clk_i : in  std_logic;
      x_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      rms_o : out std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0)
   );
end rms;

architecture structural of rms is

   signal min_s : std_logic_vector(G_SIZE-1 downto 0);   -- The minimum of x and y.
   signal max_s : std_logic_vector(G_SIZE-1 downto 0);   -- The maximum of x and y.
   signal min_r : std_logic_vector(G_SIZE-1 downto 0);
   signal max_r : std_logic_vector(G_SIZE-1 downto 0);

   constant C_NUM_LINES : integer := 6;

   -- In the structure below, the values for b were chosen as 128-i^2.
   -- And the values for a were chosen as sqrt(128^2-b^2).
   -- For this reason, the index starts at i=1.
   type t_integer_vector is array(natural range <>) of integer;
   constant a : t_integer_vector(1 to C_NUM_LINES) := ( 16,  32,  47,  62,  76, 89);
   constant b : t_integer_vector(1 to C_NUM_LINES) := (127, 124, 119, 112, 103, 92);

   -- The lines_r are calculated as the value a*x + b*y.
   type t_value_vector is array(natural range <>) of std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0);
   signal lines_r : t_value_vector(0 to C_NUM_LINES);

   -- The maximum of each pair of lines.
   signal pairs_r : t_value_vector(0 to 3);

begin

   -- Sort the x and y values, so that x <= y
   i_minmax_xy : entity work.minmax
      generic map (
         G_SIZE => G_SIZE
      )
      port map (
         a_i   => x_i,
         b_i   => y_i,
         min_o => min_s,
         max_o => max_s
      );

   -- Stage 1 : Register the sorted values.
   -- Stage 2 : Calculate the values associated with each line.
   -- Stage 3 : Find the maximum of each pair of lines.
   -- Vivado can move the registers before and after the multiplications
   -- into the DSPs, which is necessary for them to run at 108 MHz.
   p_lines : process (clk_i)
   begin
      if rising_edge(clk_i) then
         min_r <= min_s;
         max_r <= max_s;

         lines_r(0) <= max_r & (G_RESOLUTION-1 downto 0 => '0');
         for i in 1 to C_NUM_LINES loop
            lines_r(i) <= to_stdlogicvector(a(i), G_RESOLUTION) * min_r +
                          to_stdlogicvector(b(i), G_RESOLUTION) * max_r;
         end loop;

         for i in 0 to 2 loop
            if lines_r(2*i) < lines_r(2*i+1) then
               pairs_r(i) <= lines_r(2*i+1);
            else
               pairs_r(i) <= lines_r(2*i);
            end if;
         end loop;
         pairs_r(3) <= lines_r(6);
      end if;
   end process p_lines;

   -- Find the maximum of the four pairs and output it.
   -- This is done as a tree, i.e. only two comparisons in series.
   p_rms : process (pairs_r)
      variable max01_v : std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0);
      variable max23_v : std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0);
   begin
      max01_v := pairs_r(0);
      if max01_v < pairs_r(1) then
         max01_v := pairs_r(1);
      end if;

      max23_v := pairs_r(2);
      if max23_v < pairs_r(3) then
         max23_v := pairs_r(3);
      end if;

      if max01_v < max23_v then
         rms_o <= max23_v;
      else
         rms_o <= max01_v;
      end if;
   end process p_rms;

end architecture structural;
