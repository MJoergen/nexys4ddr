-- This module runs entirely in the VGA clock domain. It generates the pixel
-- position, reads the value of each pixel from the display memory, converts it
-- to a colour with the palette selected by palette_i, and generates the VGA
-- output signals for the video mode G_MODE (see video_pkg.vhd). The frame rate
-- is shown in the top right corner, see overlay.vhd.
--
-- The address of the pixel in column x and row y of the picture is
-- x*G_COL_STRIDE + y, the same as in dispatcher.vhd.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.video_pkg.all;

entity vga is
   generic (
      G_MODE       : video_mode_t;
      G_COL_STRIDE : integer
   );
   port (
      clk_i     : in  std_logic;                      -- The pixel clock
      rst_i     : in  std_logic;

      -- Read port of the display memory
      rd_addr_o : out std_logic_vector(18 downto 0);
      rd_data_i : in  std_logic_vector( 8 downto 0);

      -- Selects the palette, see palette_pkg.vhd. This is asynchronous (from
      -- the switches), and it is synchronized here.
      palette_i : in  std_logic_vector( 1 downto 0);

      -- The frame rate, moved from the MAIN clock domain in the top level
      -- (nexys4ddr.vhd or mega65_r6.vhd), see overlay.vhd
      fps_digits_i : in  std_logic_vector(31 downto 0);
      fps_blank_i  : in  std_logic_vector( 7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector( 7 downto 0)    -- RRRGGGBB
   );
end vga;

architecture structural of vga is

   -- The number of bits needed for the values 0 to n-1
   function log2 (n : integer) return integer is
      variable r : integer := 0;
   begin
      while 2**r < n loop
         r := r + 1;
      end loop;
      return r;
   end function log2;

   -- The number of bits of the rows in the visible area
   constant C_ROW_BITS : integer := log2(G_MODE.v_visible);

   signal pix_x : std_logic_vector(10 downto 0);
   signal pix_y : std_logic_vector(10 downto 0);

   -- The address of the pixel, and the address of its column. Only the lowest
   -- 19 bits are used. The multiplication by the constant G_COL_STRIDE uses
   -- LUTs, because the DSPs are for the iterators. When G_COL_STRIDE is
   -- 2**C_ROW_BITS (as on the Nexys 4 DDR), it is only wires.
   signal rd_addr : std_logic_vector(21 downto 0);
   signal rd_col  : std_logic_vector(21 downto 0);

   attribute use_dsp : string;
   attribute use_dsp of rd_col : signal is "no";

   signal disp_hs  : std_logic;
   signal disp_vs  : std_logic;
   signal disp_col : std_logic_vector(7 downto 0);

   signal palette_meta : std_logic_vector(1 downto 0) := "00";
   signal palette_sync : std_logic_vector(1 downto 0) := "00";

   attribute async_reg : string;
   attribute async_reg of palette_meta : signal is "true";
   attribute async_reg of palette_sync : signal is "true";

begin

   assert G_COL_STRIDE >= G_MODE.v_visible and
          (G_MODE.h_visible-1)*G_COL_STRIDE + G_MODE.v_visible <= 2**19
      report "The picture does not fit in the display memory"
      severity failure;

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
      generic map (
         G_MODE    => G_MODE
      )
      port map (
         clk_i     => clk_i,
         pix_x_o   => pix_x,
         pix_y_o   => pix_y
      ); -- i_pix


   -- Outside the visible area the address is not used, so the row is reduced
   -- to C_ROW_BITS bits, and the address may wrap around.
   rd_col    <= pix_x * to_slv(G_COL_STRIDE, 11);
   rd_addr   <= rd_col + pix_y(C_ROW_BITS-1 downto 0);
   rd_addr_o <= rd_addr(18 downto 0);


   --------------------------------------------------
   -- Instantiate display
   --------------------------------------------------

   i_disp : entity work.disp
      generic map (
         G_MODE       => G_MODE
      )
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
         G_DIGITS => 8,
         G_X      => G_MODE.h_visible - 8 - 16*8
      )
      port map (
         vga_clk_i    => clk_i,
         fps_digits_i => fps_digits_i,
         fps_blank_i  => fps_blank_i,
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
