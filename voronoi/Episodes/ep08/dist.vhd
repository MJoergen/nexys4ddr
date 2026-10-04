library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is a small pipelined block that computes the distance
-- between two points. The latency is 4 clock cycles: one here,
-- and three in the rms module.
entity dist is
   generic (
      G_RESOLUTION : integer;
      G_SIZE       : integer
   );
   port (
      clk_i  : in  std_logic;
      x1_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y1_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      x2_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      y2_i   : in  std_logic_vector(G_SIZE-1 downto 0);
      dist_o : out std_logic_vector(G_SIZE+G_RESOLUTION-1 downto 0)
   );
end dist;

architecture structural of dist is

   signal xmin_s  : std_logic_vector(G_SIZE-1 downto 0);
   signal xmax_s  : std_logic_vector(G_SIZE-1 downto 0);
   signal ymin_s  : std_logic_vector(G_SIZE-1 downto 0);
   signal ymax_s  : std_logic_vector(G_SIZE-1 downto 0);

   -- These contain the horizontal and vertical displacements.
   signal xdist_s : std_logic_vector(G_SIZE-1 downto 0);
   signal ydist_s : std_logic_vector(G_SIZE-1 downto 0);
   signal xdist_r : std_logic_vector(G_SIZE-1 downto 0);
   signal ydist_r : std_logic_vector(G_SIZE-1 downto 0);

begin

   -- Sort the x coordinates.
   i_minmax_x : entity work.minmax
      generic map (
         G_SIZE => G_SIZE
      )
      port map (
         a_i   => x1_i,
         b_i   => x2_i,
         min_o => xmin_s,
         max_o => xmax_s
      );

   -- Sort the y coordinates.
   i_minmax_y : entity work.minmax
      generic map (
         G_SIZE => G_SIZE
      )
      port map (
         a_i   => y1_i,
         b_i   => y2_i,
         min_o => ymin_s,
         max_o => ymax_s
      );

   -- Calculate the x and y displacements.
   xdist_s <= xmax_s - xmin_s;
   ydist_s <= ymax_s - ymin_s;

   -- Add a register to improve timing.
   p_dist : process (clk_i)
   begin
      if rising_edge(clk_i) then
         xdist_r <= xdist_s;
         ydist_r <= ydist_s;
      end if;
   end process p_dist;

   -- Calculate the distance.
   i_rms : entity work.rms
      generic map (
         G_RESOLUTION => G_RESOLUTION,
         G_SIZE       => G_SIZE
      )
      port map (
         clk_i => clk_i,
         x_i   => xdist_r,
         y_i   => ydist_r,
         rms_o => dist_o
      ); -- i_rms

end architecture structural;

