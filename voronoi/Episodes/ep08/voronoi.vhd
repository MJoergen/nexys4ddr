library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

-- This is the top level module. The ports on this entity
-- are mapped directly to pins on the FPGA.

-- In this version the design can generate a Voronoi
-- image with a single moving Voronoi point.

entity voronoi is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz

      sw_i      : in  std_logic_vector(15 downto 0);
      led_o     : out std_logic_vector(15 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)    -- RRRRGGGGBBBB
   );
end voronoi;

architecture structural of voronoi is

   constant H_PIXELS     : integer := 1280;
   constant V_PIXELS     : integer := 1024;
   constant C_RESOLUTION : integer := 7;

   -- VGA clock
   signal vga_clk_s : std_logic;
   signal vga_rst_s : std_logic;

   -- Output from VGA controller
   signal pix_x_s   : std_logic_vector(10 downto 0) := (others => '0');
   signal pix_y_s   : std_logic_vector(10 downto 0) := (others => '0');
   signal vga_hs_s  : std_logic;
   signal vga_vs_s  : std_logic;

   -- Control the movement of the Voronoi points.
   signal move_s  : std_logic;

   -- A vector of coordinates.
   type t_coord_vector is array(natural range <>) of std_logic_vector(10+C_RESOLUTION downto 0);

   constant C_NUM_POINTS : integer := 32;
   constant C_NUM_LEVELS : integer := 5;     -- log2(C_NUM_POINTS)

   -- Position of Voronoi points.
   signal vx_r       : t_coord_vector(C_NUM_POINTS-1 downto 0);
   signal vy_r       : t_coord_vector(C_NUM_POINTS-1 downto 0);

   -- Distance from current pixel to each Voronoi point.
   signal dist_s     : t_coord_vector(C_NUM_POINTS-1 downto 0);

   -- A binary tree of comparisons. Level 0 contains all the distances,
   -- and level C_NUM_LEVELS contains just the minimum distance.
   type t_colour_vector is array(natural range <>) of std_logic_vector(2 downto 0);
   type t_dist_tree     is array(0 to C_NUM_LEVELS) of t_coord_vector(0 to C_NUM_POINTS-1);
   type t_colour_tree   is array(0 to C_NUM_LEVELS) of t_colour_vector(0 to C_NUM_POINTS-1);
   signal dist_tree   : t_dist_tree;
   signal colour_tree : t_colour_tree;

   -- Colour of current pixel.
   signal mindist_d0 : std_logic_vector(10+C_RESOLUTION downto 0);
   signal colour_d0  : std_logic_vector(2 downto 0);

   -- Delay the pixel coordinates and synchronization signals, so they match
   -- the latency of the dist module (4) and the p_mindist process (6).
   constant C_LATENCY : integer := 10;
   type t_pix_vector is array(natural range <>) of std_logic_vector(10 downto 0);
   signal pix_x_d    : t_pix_vector(1 to C_LATENCY);
   signal pix_y_d    : t_pix_vector(1 to C_LATENCY);
   signal vga_hs_d   : std_logic_vector(1 to C_LATENCY);
   signal vga_vs_d   : std_logic_vector(1 to C_LATENCY);

   -- Colour of current pixel.
   signal vga_hs_d1  : std_logic;
   signal vga_vs_d1  : std_logic;
   signal vga_col_d1 : std_logic_vector(11 downto 0);

   signal sw_r       : std_logic_vector(15 downto 0) := (others => '1');
   signal sw_d       : std_logic_vector(15 downto 0) := (others => '1');

   type t_init is record
      startx : std_logic_vector(10 downto 0);
      starty : std_logic_vector(10 downto 0);
      velx   : std_logic_vector(3 downto 0);
      vely   : std_logic_vector(3 downto 0);
   end record t_init;

   function init(i : integer) return t_init is
      variable res_v : t_init;
   begin
      -- Make sure the point is not too close to the border
      res_v.startx := to_stdlogicvector(10 + ((i*46)    mod (H_PIXELS-20)), 11);
      res_v.starty := to_stdlogicvector(10 + ((i*i*37)  mod (V_PIXELS-20)), 11);
      -- Make sure the initial velocity is not zero.
      res_v.velx   := to_stdlogicvector( 1 + ((i*i*2)   mod 15),             4);
      res_v.vely   := to_stdlogicvector( 1 + ((i*i*i*3) mod 15),             4);

      return res_v;
   end function init;

begin

   --------------------------------------------------
   -- Generate 108 MHz VGA clock from 100 MHz input clock
   --------------------------------------------------

   i_clk : entity work.clk
      port map (
         clk_i => clk_i,
         clk_o => vga_clk_s
      ); -- i_clk


   ------------------------------
   -- Instantiate VGA controller
   ------------------------------
 
   i_vga : entity work.vga
      port map (
         clk_i   => vga_clk_s,
         hs_o    => vga_hs_s,
         vs_o    => vga_vs_s,
         pix_x_o => pix_x_s,
         pix_y_o => pix_y_s
      ); -- i_vga


   -------------------------------------------------------------
   -- Double buffering of switch input to remove metastability.
   -------------------------------------------------------------

   p_sw : process (vga_clk_s)
   begin
      if rising_edge(vga_clk_s) then
         sw_r <= sw_i;
         sw_d <= sw_r;
      end if;
   end process p_sw;

   vga_rst_s <= sw_d(1);

   -----------------------------------------------
   -- Signal update of Voronoi point coordinates
   -- when current pixel is outside screen area.
   -----------------------------------------------

   move_s <= sw_d(0) when pix_x_s = H_PIXELS and pix_y_s = V_PIXELS else '0';


   gen_voronoi : for i in 0 to C_NUM_POINTS-1 generate

      -- This block moves around each Voronoi center.
      i_move : entity work.move
         generic map (
            G_SIZE   => 11
         )
         port map (
            clk_i    => vga_clk_s,
            rst_i    => vga_rst_s,
            startx_i => init(i).startx,
            starty_i => init(i).starty,
            velx_i   => init(i).velx,
            vely_i   => init(i).vely,
            move_i   => move_s,
            x_o      => vx_r(i)(10+C_RESOLUTION downto C_RESOLUTION),
            y_o      => vy_r(i)(10+C_RESOLUTION downto C_RESOLUTION)
         ); -- i_move

      -- This is a small combinatorial block that computes the distance
      -- from the current pixel to the Voronoi center.
      i_dist : entity work.dist
         generic map (
            G_RESOLUTION => C_RESOLUTION,
            G_SIZE       => 11
         )
         port map (
            clk_i  => vga_clk_s,
            x1_i   => vx_r(i)(10+C_RESOLUTION downto C_RESOLUTION),
            y1_i   => vy_r(i)(10+C_RESOLUTION downto C_RESOLUTION),
            x2_i   => pix_x_s,
            y2_i   => pix_y_s,
            dist_o => dist_s(i)
         ); -- i_dist
   end generate gen_voronoi;

 
   ------------------------------------------------
   -- Delay the pixel coordinates and synchronization signals.
   ------------------------------------------------

   p_delay : process (vga_clk_s)
   begin
      if rising_edge(vga_clk_s) then
         pix_x_d  <= pix_x_s  & pix_x_d(1 to C_LATENCY-1);
         pix_y_d  <= pix_y_s  & pix_y_d(1 to C_LATENCY-1);
         vga_hs_d <= vga_hs_s & vga_hs_d(1 to C_LATENCY-1);
         vga_vs_d <= vga_vs_s & vga_vs_d(1 to C_LATENCY-1);
      end if;
   end process p_delay;


   ------------------------------------------------
   -- Determine which Voronoi point is the nearest.
   -- This is done as a binary tree, where each level
   -- halves the number of candidates. There is a register
   -- after each level, so only a single comparison
   -- is made in each clock cycle.
   ------------------------------------------------

   p_mindist : process (vga_clk_s)
   begin
      if rising_edge(vga_clk_s) then
         -- Level 0 : Register the distances, and assign a colour to each point.
         for i in 0 to C_NUM_POINTS-1 loop
            dist_tree(0)(i)   <= dist_s(i);
            colour_tree(0)(i) <= to_stdlogicvector(i mod 7, 3);
         end loop;

         -- Level l : Choose the nearest of each pair from the previous level.
         for l in 1 to C_NUM_LEVELS loop
            for i in 0 to C_NUM_POINTS/2**l-1 loop
               if dist_tree(l-1)(2*i+1) < dist_tree(l-1)(2*i) then
                  dist_tree(l)(i)   <= dist_tree(l-1)(2*i+1);
                  colour_tree(l)(i) <= colour_tree(l-1)(2*i+1);
               else
                  dist_tree(l)(i)   <= dist_tree(l-1)(2*i);
                  colour_tree(l)(i) <= colour_tree(l-1)(2*i);
               end if;
            end loop;
         end loop;
      end if;
   end process p_mindist;

   mindist_d0 <= dist_tree(C_NUM_LEVELS)(0);
   colour_d0  <= colour_tree(C_NUM_LEVELS)(0);

   
   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   p_vga_col : process (vga_clk_s)
      variable brightness_v : std_logic_vector(3 downto 0);
   begin
      if rising_edge(vga_clk_s) then
         brightness_v := not mindist_d0(C_RESOLUTION+7 downto C_RESOLUTION+4);
         case colour_d0 is
            when "000" => vga_col_d1 <= brightness_v & brightness_v & brightness_v;
            when "001" => vga_col_d1 <= brightness_v & brightness_v &       "0000";
            when "010" => vga_col_d1 <= brightness_v &       "0000" & brightness_v;
            when "011" => vga_col_d1 <= brightness_v &       "0000" &       "0000";
            when "100" => vga_col_d1 <=       "0000" & brightness_v & brightness_v;
            when "101" => vga_col_d1 <=       "0000" & brightness_v &       "0000";
            when "110" => vga_col_d1 <=       "0000" &       "0000" & brightness_v;
            when "111" => vga_col_d1 <=       "0000" &       "0000" &       "0000";
         end case;

         -- Make sure colour is black outside the visible area.
         if pix_x_d(C_LATENCY) >= H_PIXELS or pix_y_d(C_LATENCY) >= V_PIXELS then
            vga_col_d1 <= (others => '0'); -- Black colour.
         end if;

         vga_hs_d1  <= vga_hs_d(C_LATENCY);
         vga_vs_d1  <= vga_vs_d(C_LATENCY);
      end if;
   end process p_vga_col;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs_d1;
   vga_vs_o  <= vga_vs_d1;
   vga_col_o <= vga_col_d1;

   led_o <= sw_i;

end architecture structural;

