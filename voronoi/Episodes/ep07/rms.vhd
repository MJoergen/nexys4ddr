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
--
-- Calculating x/2 + 7y/8 is done by first calculating 4x+7y and then
-- dividing by 8.
-- The output is stored in 10.3 fixed point.

entity rms is
   generic (
      G_SIZE : integer
   );
   port (
      x_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      rms_o : out std_logic_vector(G_SIZE+2 downto 0)
   );
end rms;

architecture structural of rms is

   signal min_s : std_logic_vector(G_SIZE-1 downto 0);   -- The minimum of x and y.
   signal max_s : std_logic_vector(G_SIZE-1 downto 0);   -- The maximum of x and y.
   signal sum_s : std_logic_vector(G_SIZE+2 downto 0);   -- The intermediate value: 4x+7y.
   signal rms_s : std_logic_vector(G_SIZE+2 downto 0);   -- The output value.

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

   -- Calculate the intermediate value: 4x+7y.
   sum_s <= ("0" & min_s & "00")                --   4x
            + (max_s & "000")                   -- + 8y
            - ("000" & max_s);                  -- - y

   -- The values into and out of this block are stored in 10.3 fixed point.
   i_minmax_rms : entity work.minmax
      generic map (
         G_SIZE => G_SIZE+3
      )
      port map (
         a_i   => max_s & "000", -- y
         b_i   => sum_s,         -- x/2 + 7y/8.
         min_o => open,
         max_o => rms_s
      );

   rms_o <= rms_s;

end architecture structural;

