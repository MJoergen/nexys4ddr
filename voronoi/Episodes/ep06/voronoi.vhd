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

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(11 downto 0)    -- RRRRGGGGBBBB
   );
end voronoi;

architecture structural of voronoi is

   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Clock divider for VGA clock
   signal vga_cnt_r : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk_s : std_logic;

   -- Output from VGA controller
   signal pix_x_s   : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_s   : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_hs_s  : std_logic;
   signal vga_vs_s  : std_logic;

   -- Control the movement of the Voronoi points.
   signal move_s  : std_logic;

   -- A vector of coordinates.
   type t_coord_vector is array(natural range <>) of std_logic_vector(9 downto 0);

   constant C_NUM_POINTS : integer := 32;

   -- Position of Voronoi points.
   signal vx_r   : t_coord_vector(C_NUM_POINTS-1 downto 0);
   signal vy_r   : t_coord_vector(C_NUM_POINTS-1 downto 0);

   -- Distance from current pixel to each Voronoi point.
   signal dist_s : t_coord_vector(C_NUM_POINTS-1 downto 0);

   signal mindist_r : std_logic_vector(9 downto 0);
   signal colour_r  : std_logic_vector(2 downto 0);

   signal pix_x_r   : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_r   : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_hs_r  : std_logic;
   signal vga_vs_r  : std_logic;

   -- Colour of current pixel.
   signal vga_hs_d  : std_logic;
   signal vga_vs_d  : std_logic;
   signal vga_col_d : std_logic_vector(11 downto 0);

begin

   --------------------------------------------------
   -- Divide input clock by 4, from 100 MHz to 25 MHz
   -- This is close enough to 25.175 MHz.
   --------------------------------------------------

   p_vga_cnt : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_cnt_r <= vga_cnt_r + 1;
      end if;
   end process p_vga_cnt;

   vga_clk_s <= vga_cnt_r(1);


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


   -----------------------------------------------
   -- Signal update of Voronoi point coordinates
   -- when current pixel is outside screen area.
   -----------------------------------------------

   move_s <= '1' when pix_x_s = H_PIXELS and pix_y_s = V_PIXELS else '0';


   gen_voronoi : for i in 0 to C_NUM_POINTS-1 generate

      -- This block moves around each Voronoi center.
      i_move : entity work.move
         generic map (
            G_SIZE   => 10,
            -- Make sure the point is not too close to the border
            G_STARTX => to_stdlogicvector(10 + ((i*23)    mod (H_PIXELS-20)), 10),
            G_STARTY => to_stdlogicvector(10 + ((i*i*37)  mod (V_PIXELS-20)), 10),
            -- Make sure the initial velocity is not zero.
            G_VELX   => to_stdlogicvector( 1 + ((i*i*2)   mod 15),             4),
            G_VELY   => to_stdlogicvector( 1 + ((i*i*i*3) mod 15),             4)
         )
         port map (
            clk_i  => vga_clk_s,
            move_i => move_s,
            x_o    => vx_r(i),
            y_o    => vy_r(i)
         ); -- i_move

      -- This is a small combinatorial block that computes the distance
      -- from the current pixel to the Voronoi center.
      i_dist : entity work.dist
         generic map (
            G_SIZE => 10
         )
         port map (
            x1_i   => vx_r(i),
            y1_i   => vy_r(i),
            x2_i   => pix_x_s,
            y2_i   => pix_y_s,
            dist_o => dist_s(i)
         ); -- i_dist
   end generate gen_voronoi;


   ------------------------------------------------
   -- Determine which Voronoi point is the nearest
   ------------------------------------------------

   p_mindist : process (vga_clk_s)
      variable mindist_v : std_logic_vector(9 downto 0);
      variable colour_v : std_logic_vector(2 downto 0);
   begin
      if rising_edge(vga_clk_s) then
         colour_v  := "000";
         mindist_v := dist_s(0);
         for i in 1 to C_NUM_POINTS-1 loop
            if dist_s(i) < mindist_v then
               mindist_v := dist_s(i);
               colour_v  := to_stdlogicvector(i mod 7, 3);
            end if;
         end loop;

         mindist_r <= mindist_v;
         colour_r  <= colour_v;
         pix_x_r   <= pix_x_s;
         pix_y_r   <= pix_y_s;
         vga_hs_r  <= vga_hs_s;
         vga_vs_r  <= vga_vs_s;
      end if;
   end process p_mindist;

   
   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   p_vga_col : process (vga_clk_s)
      variable brightness_v : std_logic_vector(3 downto 0);
   begin
      if rising_edge(vga_clk_s) then
         brightness_v := not mindist_r(6 downto 3);
         case colour_r is
            when "000" => vga_col_d <= brightness_v & brightness_v & brightness_v;
            when "001" => vga_col_d <= brightness_v & brightness_v &       "0000";
            when "010" => vga_col_d <= brightness_v &       "0000" & brightness_v;
            when "011" => vga_col_d <= brightness_v &       "0000" &       "0000";
            when "100" => vga_col_d <=       "0000" & brightness_v & brightness_v;
            when "101" => vga_col_d <=       "0000" & brightness_v &       "0000";
            when "110" => vga_col_d <=       "0000" &       "0000" & brightness_v;
            when "111" => vga_col_d <=       "0000" &       "0000" &       "0000";
         end case;

         -- Make sure colour is black outside the visible area.
         if pix_x_r >= H_PIXELS or pix_y_r >= V_PIXELS then
            vga_col_d <= (others => '0'); -- Black colour.
         end if;

         vga_hs_d  <= vga_hs_r;
         vga_vs_d  <= vga_vs_r;
      end if;
   end process p_vga_col;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs_d;
   vga_vs_o  <= vga_vs_d;
   vga_col_o <= vga_col_d;

end architecture structural;

