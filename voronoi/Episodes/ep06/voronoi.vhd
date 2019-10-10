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

   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Clock divider for VGA clock
   signal vga_cnt_r : std_logic_vector(1 downto 0) := (others => '0');
   signal vga_clk_s : std_logic;
   signal vga_rst_s : std_logic;

   -- Output from VGA controller
   signal pix_x_s   : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_s   : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_hs_s  : std_logic;
   signal vga_vs_s  : std_logic;

   -- Control the movement of the Voronoi points.
   signal move_s  : std_logic;

   -- A vector of coordinates.
   type t_coord_vector is array(natural range <>) of std_logic_vector(12 downto 0);

   constant C_NUM_POINTS : integer := 32;

   -- Position of Voronoi points.
   signal vx_r       : t_coord_vector(C_NUM_POINTS-1 downto 0);
   signal vy_r       : t_coord_vector(C_NUM_POINTS-1 downto 0);

   -- Distance from current pixel to each Voronoi point.
   signal dist_s     : t_coord_vector(C_NUM_POINTS-1 downto 0);

   signal dist_r     : t_coord_vector(C_NUM_POINTS-1 downto 0);
   signal pix_x_r    : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_r    : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_hs_r   : std_logic;
   signal vga_vs_r   : std_logic;

   -- Colour of current pixel.
   signal mindist_d0 : std_logic_vector(12 downto 0);
   signal colour_d0  : std_logic_vector(2 downto 0);
   signal pix_x_d0   : std_logic_vector(9 downto 0) := (others => '0');
   signal pix_y_d0   : std_logic_vector(9 downto 0) := (others => '0');
   signal vga_hs_d0  : std_logic;
   signal vga_vs_d0  : std_logic;

   -- Colour of current pixel.
   signal vga_hs_d1  : std_logic;
   signal vga_vs_d1  : std_logic;
   signal vga_col_d1 : std_logic_vector(11 downto 0);

   signal sw_r       : std_logic_vector(15 downto 0) := (others => '1');
   signal sw_d       : std_logic_vector(15 downto 0) := (others => '1');

   type t_init is record
      startx : std_logic_vector(9 downto 0);
      starty : std_logic_vector(9 downto 0);
      velx   : std_logic_vector(3 downto 0);
      vely   : std_logic_vector(3 downto 0);
   end record t_init;

   function init(i : integer) return t_init is
      variable res_v : t_init;
   begin
      -- Make sure the point is not too close to the border
      res_v.startx := to_stdlogicvector(10 + ((i*23)    mod (H_PIXELS-20)), 10);
      res_v.starty := to_stdlogicvector(10 + ((i*i*37)  mod (V_PIXELS-20)), 10);
      -- Make sure the initial velocity is not zero.
      res_v.velx   := to_stdlogicvector( 1 + ((i*i*2)   mod 15),             4);
      res_v.vely   := to_stdlogicvector( 1 + ((i*i*i*3) mod 15),             4);

      return res_v;
   end function init;

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
            G_SIZE   => 10
         )
         port map (
            clk_i    => vga_clk_s,
            rst_i    => vga_rst_s,
            startx_i => init(i).startx,
            starty_i => init(i).starty,
            velx_i   => init(i).velx,
            vely_i   => init(i).vely,
            move_i   => move_s,
            x_o      => vx_r(i)(12 downto 3),
            y_o      => vy_r(i)(12 downto 3)
         ); -- i_move

      -- This is a small combinatorial block that computes the distance
      -- from the current pixel to the Voronoi center.
      i_dist : entity work.dist
         generic map (
            G_SIZE => 10
         )
         port map (
            x1_i   => vx_r(i)(12 downto 3),
            y1_i   => vy_r(i)(12 downto 3),
            x2_i   => pix_x_s,
            y2_i   => pix_y_s,
            dist_o => dist_s(i)
         ); -- i_dist
   end generate gen_voronoi;

 
   ------------------------------------------------
   -- Add a line of registers to improve timing.
   ------------------------------------------------

   p_dist : process (vga_clk_s)
   begin
      if rising_edge(vga_clk_s) then
         dist_r   <= dist_s;
         pix_x_r  <= pix_x_s;
         pix_y_r  <= pix_y_s;
         vga_hs_r <= vga_hs_s;
         vga_vs_r <= vga_vs_s;
      end if;
   end process p_dist;


   ------------------------------------------------
   -- Determine which Voronoi point is the nearest
   ------------------------------------------------

   p_mindist : process (vga_clk_s)
      variable mindist1_v : std_logic_vector(12 downto 0);
      variable colour1_v  : std_logic_vector(2 downto 0);
      variable mindist2_v : std_logic_vector(12 downto 0);
      variable colour2_v  : std_logic_vector(2 downto 0);
   begin
      if rising_edge(vga_clk_s) then

         -- Split the comparison in two, to get better timing.
         colour1_v  := "000";
         mindist1_v := dist_r(0);
         for i in 1 to C_NUM_POINTS/2-1 loop
            if dist_r(i) < mindist1_v then
               mindist1_v := dist_r(i);
               colour1_v  := to_stdlogicvector(i mod 7, 3);
            end if;
         end loop;

         colour2_v  := to_stdlogicvector((C_NUM_POINTS/2) mod 7, 3);
         mindist2_v := dist_r(C_NUM_POINTS/2);
         for i in C_NUM_POINTS/2+1 to C_NUM_POINTS-1 loop
            if dist_r(i) < mindist2_v then
               mindist2_v := dist_r(i);
               colour2_v  := to_stdlogicvector(i mod 7, 3);
            end if;
         end loop;

         if mindist1_v < mindist2_v then
            mindist_d0 <= mindist1_v;
            colour_d0  <= colour1_v;
         else
            mindist_d0 <= mindist2_v;
            colour_d0  <= colour2_v;
         end if;
         pix_x_d0   <= pix_x_r;
         pix_y_d0   <= pix_y_r;
         vga_hs_d0  <= vga_hs_r;
         vga_vs_d0  <= vga_vs_r;
      end if;
   end process p_mindist;

   
   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   p_vga_col : process (vga_clk_s)
      variable brightness_v : std_logic_vector(3 downto 0);
   begin
      if rising_edge(vga_clk_s) then
         brightness_v := not mindist_d0(9 downto 6);
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
         if pix_x_d0 >= H_PIXELS or pix_y_d0 >= V_PIXELS then
            vga_col_d1 <= (others => '0'); -- Black colour.
         end if;

         vga_hs_d1  <= vga_hs_d0;
         vga_vs_d1  <= vga_vs_d0;
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

