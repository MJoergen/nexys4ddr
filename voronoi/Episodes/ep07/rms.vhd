library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a small combinatorial block that computes an
-- approximation to the RMS of two values, i.e.
-- rms = sqrt(x^2 + y^2).
-- The approximation boils down to (assuming 0 < x < y).
--
-- 32*rms =        32*y when         x <  y/8
-- 32*rms =  8*x + 31*y when  y/8 <= x < 2y/5
-- 32*rms = 18*x + 27*y when 2y/5 <= x
--
-- The output is stored in 10.5 fixed point.


entity rms is
   generic (
      G_SIZE : integer
   );
   port (
      x_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      rms_o : out std_logic_vector(G_SIZE+4 downto 0)
   );
end rms;

architecture structural of rms is

   signal min_s     : std_logic_vector(G_SIZE-1 downto 0);   -- The minimum of x and y.
   signal max_s     : std_logic_vector(G_SIZE-1 downto 0);   -- The maximum of x and y.
   signal line1_s   : std_logic_vector(G_SIZE+4 downto 0);   -- The intermediate value: 12x + 29y
   signal line2_s   : std_logic_vector(G_SIZE+4 downto 0);   -- The intermediate value: 20x + 25y.
   signal linemax_s : std_logic_vector(G_SIZE+4 downto 0);
   signal rms_s     : std_logic_vector(G_SIZE+4 downto 0);   -- The output value.

begin

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

   -- Calculate 8x + 31y
   line1_s <=  ("00" & min_s & "000")  --   8x
             + (max_s & "00000")       -- +32y
             - ("00000" & max_s);      -- -  y

   -- Calculate 18x + 27y
   line2_s <=  ("0" & min_s & "0000")  --  16x
             + ("0000" & min_s & "0")  -- + 2x
             + (     max_s & "00000")  -- +32y
             - ("000" & max_s & "00")  -- - 4y
             - ("00000" & max_s);      -- -  y

   i_minmax_linemax : entity work.minmax
      generic map (
         G_SIZE => G_SIZE+5
      )
      port map (
         a_i   => line1_s,
         b_i   => line2_s,
         min_o => open,
         max_o => linemax_s
      );

   -- The values into and out of this block are stored in 10.5 fixed point.
   i_minmax_rms : entity work.minmax
      generic map (
         G_SIZE => G_SIZE+5
      )
      port map (
         a_i   => max_s & "00000", -- y
         b_i   => linemax_s,
         min_o => open,
         max_o => rms_s
      );

   rms_o <= rms_s;

end architecture structural;

