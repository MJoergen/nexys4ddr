library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a small combinatorial block that computes a (very crude)
-- approximation to the RMS of two values, i.e.
-- rms = sqrt(x^2 + y^2).
-- The crude approximation boils down to (assuming 0 < x < y):
-- rms = y       when        x < y/2
-- rms = x + y/2 when y/2 <= x <= y
-- For fixed y this gives a piecewise linear function that increases from y to 3y/2.
-- The true value at x=y is rms = sqrt(2)*y = 1.4*y.
-- This has a maximum error of about 0.12*y at x=y/2.

entity rms is
   generic (
      G_SIZE : integer
   );
   port (
      x_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      rms_o : out std_logic_vector(G_SIZE-1 downto 0)
   );
end rms;

architecture structural of rms is

   signal min_s : std_logic_vector(G_SIZE-1 downto 0);   -- The minimum of x and y.
   signal max_s : std_logic_vector(G_SIZE-1 downto 0);   -- The maximum of x and y.
   signal sum_s : std_logic_vector(G_SIZE-1 downto 0);   -- The intermediate value: x + y/2.
   signal rms_s : std_logic_vector(G_SIZE-1 downto 0);   -- The output value.

begin

   -- Sort the input lengths. This is needed for the approximation to work.
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

   -- Calculate x + y/2.
   sum_s <= min_s                                  -- x
            + ("0" & max_s(G_SIZE-1 downto 1));    -- y/2

   -- The piecewise function is constructed simply
   -- by taking the maximum of the two linear pieces.
   i_minmax_rms : entity work.minmax
      generic map (
         G_SIZE => G_SIZE
      )
      port map (
         a_i   => max_s,
         b_i   => sum_s,
         min_o => open,
         max_o => rms_s
      );

   rms_o <= rms_s;

end architecture structural;

