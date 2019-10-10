library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a small combinatorial block that computes an
-- approximation to the RMS of two values, i.e.
-- rms = sqrt(x^2 + y^2).
-- The approximation boils down to (assuming 0 < x < y).
-- rms = y          when        x < y/4
-- rms = x/2 + 7y/8 when y/4 <= x <= y
-- This has a maximum error of about 0.039*y at x=y.

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

   -- Calculate x/2 + 7y/8.
   sum_s <= ("0" & min_s(G_SIZE-1 downto 1))       -- x/2
            + max_s                                -- y
            - ("000" & max_s(G_SIZE-1 downto 3));  -- y/8

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

