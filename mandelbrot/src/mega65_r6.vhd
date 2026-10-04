library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.video_pkg.all;

-- This is the top level module for the MEGA65 (board revision R6). The ports
-- on this entity are mapped directly to pins on the FPGA, see mega65-r6.xdc.
--
-- It is the same design as nexys4ddr.vhd (the top level module for the
-- Nexys 4 DDR board), only the resolution and the ports are different:
-- * The VGA output is 800x600 @ 60 Hz, with a pixel clock of 40 MHz, instead
--   of 640x480.
-- * There are no buttons and switches. Instead, the view is controlled by the
--   joysticks: The directions of joystick port 1 (fa_*) pan the view, and the
--   fire button of port 1 zooms in. The fire button of port 2 (fb_*) zooms
--   out.
-- * The palette can not be selected, so palette 0 is always used.
-- * There is no 7-segment display, so the frame rate is only shown on the VGA
--   output.
-- * The VGA output goes through a video DAC with 8 bits per colour. The DAC
--   needs a clock, which is the VGA clock inverted, so the DAC samples the
--   pixel colour in the middle of each pixel.

entity mega65_r6 is
   port (
      clk_i          : in  std_logic;                      -- 100 MHz
      reset_button_i : in  std_logic;                      -- Active high

      -- Joystick ports, active low
      fa_up_n_i      : in  std_logic;
      fa_down_n_i    : in  std_logic;
      fa_left_n_i    : in  std_logic;
      fa_right_n_i   : in  std_logic;
      fa_fire_n_i    : in  std_logic;
      fb_fire_n_i    : in  std_logic;

      -- VGA via the video DAC
      vga_red_o      : out std_logic_vector(7 downto 0);
      vga_green_o    : out std_logic_vector(7 downto 0);
      vga_blue_o     : out std_logic_vector(7 downto 0);
      vga_hs_o       : out std_logic;
      vga_vs_o       : out std_logic;
      vdac_clk_o     : out std_logic;
      vdac_sync_n_o  : out std_logic;
      vdac_blank_n_o : out std_logic;
      vdac_psave_n_o : out std_logic
   );
end mega65_r6;

architecture structural of mega65_r6 is

   -- The number of column modules. The XC7A200T has 740 DSPs, but the number
   -- of column modules is limited by the slices: 240 column modules use 93% of
   -- the slices of the XC7A100T, and the XC7A200T has 2.1 times as many.
   constant C_NUM_ITERATORS : integer := 450;

   -- The number of pixels in each write to the display memory. The dispatcher
   -- accepts at most one result per clock cycle, so with one pixel in each
   -- write the picture takes at least 800*600 clock cycles (2.55 ms), and
   -- more column modules give little more. The model (sim/model.py) estimates
   -- 1.32 ms for the initial picture with four pixels in each write, against
   -- 2.72 ms with one.
   constant C_PIXELS        : integer := 4;

   -- The video mode (see video_pkg.vhd), and the divider of the VGA clock,
   -- which gives the pixel clock (1200 MHz / 30 = 40 MHz, see clk_rst.vhd).
   constant C_VIDEO         : video_mode_t := C_VIDEO_800X600;
   constant C_VGA_DIVIDE    : integer := 30;

   -- The divider of the MAIN clock (see clk_rst.vhd), and its frequency in Hz.
   -- 1200 MHz / 6.375 = 188.235 MHz. The model (sim/model.py) estimates 1.66
   -- million clock cycles for the worst case picture (every pixel needs the
   -- maximum count), i.e. 113 pictures per second.
   constant C_MAIN_DIVIDE   : real    := 6.375;
   constant C_MAIN_FREQ     : natural := natural(1200.0E6 / C_MAIN_DIVIDE);

   -- The address distance between two picture columns in the display memory,
   -- see dispatcher.vhd. With 1024 addresses per column (the column followed
   -- by the row) the picture would not fit in the 2^19 pixels of the display
   -- memory, so each column has 600 addresses, one for each row.
   constant C_COL_STRIDE    : integer := 600;

   signal rstn           : std_logic;
   signal btn            : std_logic_vector( 4 downto 0);  -- "CLRUD"
   signal sw             : std_logic_vector( 7 downto 0);

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

   signal vga_col        : std_logic_vector( 7 downto 0);  -- RRRGGGBB

begin

   --------------------------------------------------
   -- Map the joysticks to the buttons and switches
   --------------------------------------------------

   rstn <= not reset_button_i;

   -- Both fire buttons zoom, switch 2 selects zoom out.
   btn <= not (fa_fire_n_i and fb_fire_n_i) & not fa_left_n_i & not fa_right_n_i &
          not fa_up_n_i & not fa_down_n_i;
   sw  <= "00000" & not fb_fire_n_i & "00";


   --------------------------------------------------
   -- Instantiate clock and reset generation
   --------------------------------------------------

   i_clk_rst : entity work.clk_rst
      generic map (
         G_MAIN_DIVIDE => C_MAIN_DIVIDE,
         G_VGA_DIVIDE  => C_VGA_DIVIDE
      )
      port map (
         clk_i      => clk_i,
         rstn_i     => rstn,
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
         G_CLK_FREQ      => C_MAIN_FREQ,
         G_NUM_ITERATORS => C_NUM_ITERATORS,
         G_PIXELS        => C_PIXELS,
         G_NUM_COLS      => C_VIDEO.h_visible,
         G_NUM_ROWS      => C_VIDEO.v_visible,
         G_COL_STRIDE    => C_COL_STRIDE
      )
      port map (
         clk_i     => main_clk,
         rst_i     => main_rst,
         btn_i     => btn,
         sw_i      => sw,
         seg_o     => open,
         seg_an_o  => open,
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


   --------------------------------------------------
   -- Move the frame rate to the VGA clock domain
   --------------------------------------------------

   -- The same as in nexys4ddr.vhd, see there.
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
         palette_i => sw(1 downto 0),
         fps_digits_i => vga_fps_digits,
         fps_blank_i  => vga_fps_blank,
         vga_hs_o  => vga_hs_o,
         vga_vs_o  => vga_vs_o,
         vga_col_o => vga_col
      ); -- i_vga


   --------------------------------------------------
   -- Video DAC
   --------------------------------------------------

   -- Expand each colour to 8 bits by repeating the bits, so that the full
   -- range is used (e.g. "111" becomes "11111111").
   vga_red_o   <= vga_col(7 downto 5) & vga_col(7 downto 5) & vga_col(7 downto 6);
   vga_green_o <= vga_col(4 downto 2) & vga_col(4 downto 2) & vga_col(4 downto 3);
   vga_blue_o  <= vga_col(1 downto 0) & vga_col(1 downto 0) & vga_col(1 downto 0) & vga_col(1 downto 0);

   -- The DAC samples the colour on the rising edge of its clock. The clock is
   -- low in the first half of the VGA clock cycle and high in the second half,
   -- i.e. the VGA clock inverted.
   i_vdac_clk : ODDR
      generic map (
         DDR_CLK_EDGE => "SAME_EDGE",
         INIT         => '0',
         SRTYPE       => "SYNC"
      )
      port map (
         Q  => vdac_clk_o,
         C  => vga_clk,
         CE => '1',
         D1 => '0',
         D2 => '1',
         R  => '0',
         S  => '0'
      ); -- i_vdac_clk

   vdac_sync_n_o  <= '0';  -- No sync on green
   vdac_blank_n_o <= '1';  -- The colour is black outside the visible area
   vdac_psave_n_o <= '1';  -- Power on

end architecture structural;
