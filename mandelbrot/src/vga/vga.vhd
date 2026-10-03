library ieee;
use ieee.std_logic_1164.all;

-- This module runs entirely in the VGA clock domain (25 MHz). It generates the
-- pixel position, reads the value of each pixel from the display memory,
-- converts it to a colour with the palette selected by palette_i, and generates
-- the VGA output signals (640x480). The frame rate is shown in the top right
-- corner, see overlay.vhd.

entity vga is
   port (
      clk_i     : in  std_logic;                      -- 25 MHz
      rst_i     : in  std_logic;

      -- Read port of the display memory
      rd_addr_o : out std_logic_vector(18 downto 0);
      rd_data_i : in  std_logic_vector( 8 downto 0);

      -- Selects the palette, see palette_pkg.vhd. This is asynchronous (from
      -- the switches), and it is synchronized here.
      palette_i : in  std_logic_vector( 1 downto 0);

      -- The frame rate, from the MAIN clock domain, see overlay.vhd
      fps_digits_i : in  std_logic_vector(31 downto 0);
      fps_blank_i  : in  std_logic_vector( 7 downto 0);
      fps_toggle_i : in  std_logic;

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector( 7 downto 0)    -- RRRGGGBB
   );
end vga;

architecture structural of vga is

   signal pix_x : std_logic_vector(9 downto 0);
   signal pix_y : std_logic_vector(9 downto 0);

   signal disp_hs  : std_logic;
   signal disp_vs  : std_logic;
   signal disp_col : std_logic_vector(7 downto 0);

   signal palette_meta : std_logic_vector(1 downto 0) := "00";
   signal palette_sync : std_logic_vector(1 downto 0) := "00";

   attribute async_reg : string;
   attribute async_reg of palette_meta : signal is "true";
   attribute async_reg of palette_sync : signal is "true";

begin

   --------------------------------------------------
   -- Synchronize the palette selection
   --------------------------------------------------

   p_palette : process (clk_i)
   begin
      if rising_edge(clk_i) then
         palette_meta <= palette_i;
         palette_sync <= palette_meta;
      end if;
   end process p_palette;


   --------------------------------------------------
   -- Instantiate pixel counters
   --------------------------------------------------

   i_pix : entity work.pix
      port map (
         clk_i     => clk_i,
         pix_x_o   => pix_x,
         pix_y_o   => pix_y
      ); -- i_pix


   rd_addr_o <= pix_x & pix_y(8 downto 0);


   --------------------------------------------------
   -- Instantiate display
   --------------------------------------------------

   i_disp : entity work.disp
      port map (
         vga_clk_i    => clk_i,
         vga_rst_i    => rst_i,
         vga_pix_x_i  => pix_x,
         vga_pix_y_i  => pix_y,
         vga_col_d3_i => rd_data_i,
         vga_palette_i=> palette_sync,
         vga_hs_o     => disp_hs,
         vga_vs_o     => disp_vs,
         vga_col_o    => disp_col
      ); -- i_disp


   --------------------------------------------------
   -- Instantiate frame rate overlay
   --------------------------------------------------

   i_overlay : entity work.overlay
      generic map (
         G_DIGITS => 8
      )
      port map (
         vga_clk_i    => clk_i,
         fps_digits_i => fps_digits_i,
         fps_blank_i  => fps_blank_i,
         fps_toggle_i => fps_toggle_i,
         vga_pix_x_i  => pix_x,
         vga_pix_y_i  => pix_y,
         vga_hs_d4_i  => disp_hs,
         vga_vs_d4_i  => disp_vs,
         vga_col_d4_i => disp_col,
         vga_hs_o     => vga_hs_o,
         vga_vs_o     => vga_vs_o,
         vga_col_o    => vga_col_o
      ); -- i_overlay

end architecture structural;
