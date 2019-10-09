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
      vga_col_o : out std_logic_vector(7 downto 0)    -- RRRGGGBB
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

   -- Coordinates of the Voronoi point.
   signal vx_s      : std_logic_vector(9 downto 0);
   signal vy_s      : std_logic_vector(9 downto 0);

   -- Distance from current pixel to Voronoi point.
   signal dist_s    : std_logic_vector(9 downto 0);

   -- Colour of current pixel.
   signal vga_col_r : std_logic_vector(7 downto 0);

   signal move_s    : std_logic;

   -- Convert from RGB format to 8-bit VGA colour.
   function vga_col(r : integer; g : integer; b : integer) return std_logic_vector is
   begin
      return to_stdlogicvector(r, 3) & to_stdlogicvector(g, 3) & to_stdlogicvector(b, 2);
   end function vga_col;

   type t_col_vector is array(natural range <>) of std_logic_vector(7 downto 0);

   -- List of 16 colours
   constant C_COLORS : t_col_vector :=
   (
      vga_col(7,7,3),
      vga_col(6,7,3),
      vga_col(6,6,3),
      vga_col(5,6,3),
      vga_col(5,5,3),
      vga_col(5,5,2),
      vga_col(4,5,2),
      vga_col(4,4,2),
      vga_col(3,4,2),
      vga_col(3,3,2),
      vga_col(3,3,1),
      vga_col(2,3,1),
      vga_col(2,2,1),
      vga_col(1,2,1),
      vga_col(1,1,1),
      vga_col(1,1,0)
   );

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


   ------------------------------------------------
   -- This block moves around each Voronoi center.
   ------------------------------------------------

   i_move : entity work.move
      generic map (
         G_SIZE   => 10,
         G_STARTX => to_stdlogicvector(400, 10),
         G_STARTY => to_stdlogicvector(300, 10)
      )
      port map (
         clk_i  => vga_clk_s,
         move_i => move_s,
         x_o    => vx_s,
         y_o    => vy_s
      ); -- i_move


   ------------------------------------------------------------
   -- This is a small combinatorial block that computes the
   -- distance from the current pixel to the Voronoi center.
   ------------------------------------------------------------

   i_dist : entity work.dist
      generic map (
         G_SIZE => 10
      )
      port map (
         x1_i   => vx_s,
         y1_i   => vy_s,
         x2_i   => pix_x_s,
         y2_i   => pix_y_s,
         dist_o => dist_s
      ); -- i_dist


   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   p_vga_col : process (vga_clk_s)
   begin
      if rising_edge(vga_clk_s) then

         vga_col_r <= C_COLORS(to_integer(dist_s(7 downto 4)));

         -- Make sure colour is black outside the visible area.
         if pix_x_s >= H_PIXELS or pix_y_s >= V_PIXELS then
            vga_col_r <= (others => '0'); -- Black colour.
         end if;
      end if;
   end process p_vga_col;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_hs_o  <= vga_hs_s;
   vga_vs_o  <= vga_vs_s;
   vga_col_o <= vga_col_r;

end architecture structural;

