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
-- The output is stored in 10.5 fixed point.

entity rms is
   generic (
      G_RESOLUTION : integer;
      G_SIZE       : integer
   );
   port (
      x_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      rms_o : out std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0)
   );
end rms;

architecture structural of rms is

   signal min_s : std_logic_vector(G_SIZE-1 downto 0);   -- The minimum of x and y.
   signal max_s : std_logic_vector(G_SIZE-1 downto 0);   -- The maximum of x and y.

   constant C_NUM_LINES : integer := 6;

   -- In the structure below, the values for b where chosen as 128-i^2.
   -- And the values for a where chosen as sqrt(128^2-b^2).
   -- For this reason, the index starts at i=1.
   type t_integer_vector is array(natural range <>) of integer;
   constant a : t_integer_vector(1 to C_NUM_LINES) := ( 16,  32,  47,  62,  76, 89);
   constant b : t_integer_vector(1 to C_NUM_LINES) := (127, 124, 119, 112, 103, 92);

   -- The lines_s are calculated as the value a*x + b*y.
   type t_value_vector is array(natural range <>) of std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0);
   signal lines_s : t_value_vector(1 to C_NUM_LINES);

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

   -- Calculate the values associated with each line.
   -- Unfortunately, this implementation leads Vivado to infer
   -- DSPs to do the multiplications. I would have preferred (or expected)
   -- Vivado to generate a series of additions, since we're multiplying
   -- with a constant. However, even without registers on the DSP output
   -- this is far from timing critical, at least at 25 MHz.
   gen_lines : for i in 1 to C_NUM_LINES generate
      lines_s(i) <= to_stdlogicvector(a(i), G_RESOLUTION) * min_s +
                    to_stdlogicvector(b(i), G_RESOLUTION) * max_s;
   end generate gen_lines;

   -- Find the maximum value and output it.
   p_rms : process (lines_s)
      variable rms_v : std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0);
   begin
      rms_v := max_s & "0000000";
      for i in 1 to C_NUM_LINES loop -- Skip index 0.
         if rms_v < lines_s(i) then
            rms_v := lines_s(i);
         end if;
      end loop;

      rms_o <= rms_v;
   end process p_rms;

end architecture structural;

