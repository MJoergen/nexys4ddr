library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

use work.video_pkg.all;

-- This is the top level module. The ports on this entity are mapped directly
-- to pins on the FPGA.
--
-- The design calculates the Mandelbrot set, and shows it on the VGA output
-- (640x480 @ 60 Hz). The picture is calculated by the dispatcher and stored in
-- the display memory. As soon as one picture is finished, the calculation of
-- the next picture is started, so the picture is recalculated continuously.
--
-- The design is split into two modules, one for each clock domain: main.vhd
-- (MAIN clock) and vga.vhd (VGA clock). The two domains communicate through
-- the display memory, and the frame rate (see below). This module
-- instantiates the clock and reset generation, the display memory, and the
-- two modules above.
--
-- The buttons, switches and the 7-segment display are handled by main.vhd,
-- see the description there, except switches 0 and 1, which select the colour
-- palette in vga.vhd (see palette_pkg.vhd). The decimal point of the 7-segment
-- display is not used, so it is switched off here.
--
-- The frame rate is calculated in main.vhd, and also shown on the VGA output by
-- vga.vhd. This is the only signal between the two clock domains, apart from
-- the display memory. It is moved to the VGA clock domain here (p_fps_cdc):
-- main.vhd changes fps_toggle each time it changes fps_digits and fps_blank
-- (in the same clock cycle). fps_toggle is synchronized, and the frame rate is
-- copied when the change is seen. The frame rate is constant for much longer
-- than the synchronizer takes, so it is never copied while it changes. The
-- constraints for this are in nexys4ddr.xdc.

entity nexys4ddr is
   port (
      clk_i     : in  std_logic;                      -- 100 MHz
      rstn_i    : in  std_logic;

      btn_i     : in  std_logic_vector( 4 downto 0);  -- "CLRUD"
      sw_i      : in  std_logic_vector( 7 downto 0);
      seg_o     : out std_logic_vector( 6 downto 0);  -- "GFEDCBA", active low
      seg_dp_o  : out std_logic;                      -- Active low
      seg_an_o  : out std_logic_vector( 7 downto 0);  -- Active low

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector( 7 downto 0)    -- RRRGGGBB
   );
end nexys4ddr;

architecture structural of nexys4ddr is

   -- The number of column modules. The XC7A100T has 240 DSPs, one for each
   -- column module.
   constant C_NUM_ITERATORS : integer := 240;

   -- The number of pixels in each write to the display memory. Writing more
   -- than one pixel at a time makes the picture faster (see mega65_r6.vhd).
   -- With four pixels the model estimates 1.11 ms for the initial picture,
   -- against 1.84 ms, but the design then uses 97.5% of the slices of the
   -- XC7A100T, and has only +0.012 ns of setup slack (see ALGORITHM.md).
   constant C_PIXELS        : integer := 1;

   -- The video mode (see video_pkg.vhd), and the divider of the VGA clock,
   -- which gives the pixel clock (1200 MHz / 48 = 25 MHz, see clk_rst.vhd).
   constant C_VIDEO         : video_mode_t := C_VIDEO_640X480;
   constant C_VGA_DIVIDE    : integer := 48;

   -- The address distance between two picture columns in the display memory,
   -- see dispatcher.vhd. 512 rows per column means the address is the column
   -- followed by the row.
   constant C_COL_STRIDE    : integer := 512;

   signal main_clk       : std_logic;
   signal main_rst       : std_logic;

   signal vga_clk        : std_logic;
   signal vga_rst        : std_logic;

   signal wr_addr        : std_logic_vector(18 downto 0);
   signal wr_data        : std_logic_vector(9*C_PIXELS-1 downto 0);
   signal wr_en          : std_logic;

   signal rd_addr        : std_logic_vector(18 downto 0);
   signal rd_data        : std_logic_vector( 8 downto 0);

   signal fps_digits     : std_logic_vector(31 downto 0);
   signal fps_blank      : std_logic_vector( 7 downto 0);
   signal fps_toggle     : std_logic;

   -- The frame rate in the VGA clock domain. Nothing is shown (all digits are
   -- blanked) until the first frame rate is received.
   signal vga_fps_meta   : std_logic := '0';
   signal vga_fps_sync   : std_logic := '0';
   signal vga_fps_sync_d : std_logic := '0';
   signal vga_fps_digits : std_logic_vector(31 downto 0) := (others => '0');
   signal vga_fps_blank  : std_logic_vector( 7 downto 0) := (others => '1');

   attribute async_reg : string;
   attribute async_reg of vga_fps_meta : signal is "true";
   attribute async_reg of vga_fps_sync : signal is "true";

begin

   --------------------------------------------------
   -- Instantiate clock and reset generation
   --------------------------------------------------

   i_clk_rst : entity work.clk_rst
      generic map (
         G_VGA_DIVIDE => C_VGA_DIVIDE
      )
      port map (
         clk_i      => clk_i,
         rstn_i     => rstn_i,
         main_clk_o => main_clk,
         main_rst_o => main_rst,
         vga_clk_o  => vga_clk,
         vga_rst_o  => vga_rst
      ); -- i_clk_rst


   --------------------------------------------------
   -- Instantiate MAIN clock domain
   --------------------------------------------------

   i_main : entity work.main
      generic map (
         G_NUM_ITERATORS => C_NUM_ITERATORS,
         G_PIXELS        => C_PIXELS,
         G_NUM_COLS      => C_VIDEO.h_visible,
         G_NUM_ROWS      => C_VIDEO.v_visible,
         G_COL_STRIDE    => C_COL_STRIDE
      )
      port map (
         clk_i     => main_clk,
         rst_i     => main_rst,
         btn_i     => btn_i,
         sw_i      => sw_i,
         seg_o     => seg_o,
         seg_an_o  => seg_an_o,
         fps_digits_o => fps_digits,
         fps_blank_o  => fps_blank,
         fps_toggle_o => fps_toggle,
         wr_addr_o => wr_addr,
         wr_data_o => wr_data,
         wr_en_o   => wr_en
      ); -- i_main


   ------------------------------
   -- Instantiate display memory
   ------------------------------

   i_disp_mem : entity work.disp_mem
      generic map (
         G_PIXELS => C_PIXELS
      )
      port map (
         wr_clk_i  => main_clk,
         wr_rst_i  => main_rst,
         wr_addr_i => wr_addr,
         wr_data_i => wr_data,
         wr_en_i   => wr_en,
         --
         rd_clk_i  => vga_clk,
         rd_rst_i  => vga_rst,
         rd_addr_i => rd_addr,
         rd_data_o => rd_data
      ); -- i_disp_mem


   seg_dp_o <= '1';


   --------------------------------------------------
   -- Move the frame rate to the VGA clock domain
   --------------------------------------------------

   p_fps_cdc : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vga_fps_meta   <= fps_toggle;
         vga_fps_sync   <= vga_fps_meta;
         vga_fps_sync_d <= vga_fps_sync;

         if vga_fps_sync /= vga_fps_sync_d then
            vga_fps_digits <= fps_digits;
            vga_fps_blank  <= fps_blank;
         end if;
      end if;
   end process p_fps_cdc;


   --------------------------------------------------
   -- Instantiate VGA clock domain
   --------------------------------------------------

   i_vga : entity work.vga
      generic map (
         G_MODE       => C_VIDEO,
         G_COL_STRIDE => C_COL_STRIDE
      )
      port map (
         clk_i     => vga_clk,
         rst_i     => vga_rst,
         rd_addr_o => rd_addr,
         rd_data_i => rd_data,
         palette_i => sw_i(1 downto 0),
         fps_digits_i => vga_fps_digits,
         fps_blank_i  => vga_fps_blank,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col_o
      ); -- i_vga

end architecture structural;
