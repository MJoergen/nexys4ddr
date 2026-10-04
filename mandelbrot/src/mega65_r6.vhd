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
-- Nexys 4 DDR board), only the size of the design, the resolution and the
-- ports are different:
-- * The VGA output is 1280x1024 @ 60 Hz, with a pixel clock of 108 MHz,
--   instead of 640x480. The display memory is 2.5 times as large.
-- * There are no buttons and switches. Instead, the view is controlled by the
--   joysticks: The directions of joystick port 1 (fa_*) pan the view, and the
--   fire button of port 1 zooms in. The fire button of port 2 (fb_*) zooms
--   out.
-- * The palette can not be selected, so palette 0 is always used.
-- * There is no 7-segment display, so the frame rate is only shown on the VGA
--   output.
-- * The VGA output goes through a video DAC with 8 bits per colour. The DAC
--   needs a clock, which is the VGA clock inverted, so the DAC samples the
--   pixel colour in the middle of each pixel. The colour and the sync signals
--   are registered in the IOBs, so they all change at the same time, half a
--   clock cycle (4.6 ns) before the DAC samples them.

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
   -- of column modules is limited by the routing: With 800x600, 450 column
   -- modules fit, but with 1280x1024 the display memory uses 320 of the 365
   -- BRAMs, and with 450 column modules the routing did not finish. 256
   -- column modules use 58% of the slices.
   constant C_NUM_ITERATORS : integer := 256;

   -- The number of pixels in each write to the display memory. The dispatcher
   -- accepts at most one result per clock cycle, so with one pixel in each
   -- write the picture takes at least 1280*1024 clock cycles (8.80 ms), and
   -- more column modules give little more. The model (sim/model.py) estimates
   -- 4.91 ms for the initial picture with four pixels in each write, against
   -- 9.76 ms with one.
   constant C_PIXELS        : integer := 4;

   -- The VCO of the MMCM (see clk_rst.vhd): 100 MHz / 5 * 54 = 1080 MHz. This
   -- is the only VCO frequency which gives the pixel clock of 108 MHz exactly.
   constant C_VCO_DIVIDE    : integer := 5;
   constant C_VCO_MULT      : real    := 54.0;

   -- The video mode (see video_pkg.vhd), and the divider of the VGA clock,
   -- which gives the pixel clock (1080 MHz / 10 = 108 MHz, see clk_rst.vhd).
   constant C_VIDEO         : video_mode_t := C_VIDEO_1280X1024;
   constant C_VGA_DIVIDE    : integer := 10;

   -- The divider of the MAIN clock (see clk_rst.vhd), and its frequency in Hz.
   -- 1080 MHz / 7.25 = 148.97 MHz. The model (sim/model.py) estimates 7.9
   -- million clock cycles for the worst case picture (every pixel needs the
   -- maximum count), i.e. 18 pictures per second, against 203 for the initial
   -- picture. 1080 MHz / 5.75 = 187.83 MHz failed timing with 450 column
   -- modules.
   constant C_MAIN_DIVIDE   : real    := 7.25;
   constant C_MAIN_FREQ     : natural :=
      natural(100.0E6 / real(C_VCO_DIVIDE) * C_VCO_MULT / C_MAIN_DIVIDE);

   -- Rows in each job given to a column module, see dispatcher.vhd. The
   -- number of rows (1024) must be a multiple of it, and of C_PIXELS. The
   -- model gives 199 to 203 pictures per second for 32 to 128 rows.
   constant C_JOB_ROWS      : integer := 64;

   -- The address distance between two picture columns in the display memory,
   -- see dispatcher.vhd. 1024 rows per column means the address is the column
   -- (11 bits) followed by the row (10 bits).
   constant C_COL_STRIDE    : integer := 1024;

   -- The display memory (see disp_mem.vhd): 1280*1024 pixels, i.e. 320 blocks
   -- (BRAMs) of 4096 pixels, with 21 bits of address. The XC7A200T has 365
   -- BRAMs. Without a register for the write port of each block, the register
   -- of each group of 8 blocks drives their BRAMs directly. This saves about
   -- 15,000 registers, which made the slices too full for the column modules
   -- (92% used, and the MAIN clock failed timing).
   constant C_ADDR_BITS     : integer := 21;
   constant C_MEM_BLOCKS    : integer := 320;
   constant C_BLOCK_REGS    : boolean := false;

   signal rstn           : std_logic;
   signal btn            : std_logic_vector( 4 downto 0);  -- "CLRUD"
   signal sw             : std_logic_vector( 7 downto 0);

   signal main_clk       : std_logic;
   signal main_rst       : std_logic;

   signal vga_clk        : std_logic;
   signal vga_rst        : std_logic;

   signal wr_addr        : std_logic_vector(C_ADDR_BITS-1 downto 0);
   signal wr_data        : std_logic_vector(9*C_PIXELS-1 downto 0);
   signal wr_en          : std_logic;

   signal rd_addr        : std_logic_vector(C_ADDR_BITS-1 downto 0);
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

   signal vga_hs         : std_logic;
   signal vga_vs         : std_logic;
   signal vga_col        : std_logic_vector( 7 downto 0);  -- RRRGGGBB

   -- The registers of the outputs to the DAC and the VGA connector. Several of
   -- the colour registers are identical, so the attribute keep prevents the
   -- synthesis tool from merging them, and the attribute IOB places them in
   -- the IOBs.
   signal vdac_red_r     : std_logic_vector( 7 downto 0);
   signal vdac_green_r   : std_logic_vector( 7 downto 0);
   signal vdac_blue_r    : std_logic_vector( 7 downto 0);
   signal vdac_hs_r      : std_logic;
   signal vdac_vs_r      : std_logic;

   attribute keep : string;
   attribute keep of vdac_red_r   : signal is "true";
   attribute keep of vdac_green_r : signal is "true";
   attribute keep of vdac_blue_r  : signal is "true";

   attribute iob : string;
   attribute iob of vdac_red_r   : signal is "true";
   attribute iob of vdac_green_r : signal is "true";
   attribute iob of vdac_blue_r  : signal is "true";
   attribute iob of vdac_hs_r    : signal is "true";
   attribute iob of vdac_vs_r    : signal is "true";

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
         G_VCO_DIVIDE  => C_VCO_DIVIDE,
         G_VCO_MULT    => C_VCO_MULT,
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
         G_JOB_ROWS      => C_JOB_ROWS,
         G_NUM_COLS      => C_VIDEO.h_visible,
         G_NUM_ROWS      => C_VIDEO.v_visible,
         G_COL_STRIDE    => C_COL_STRIDE,
         G_ADDR_BITS     => C_ADDR_BITS
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
         G_ADDR_BITS  => C_ADDR_BITS,
         G_NUM_BLOCKS => C_MEM_BLOCKS,
         G_BLOCK_REGS => C_BLOCK_REGS,
         G_PIXELS     => C_PIXELS
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
         G_COL_STRIDE => C_COL_STRIDE,
         G_ADDR_BITS  => C_ADDR_BITS
      )
      port map (
         clk_i     => vga_clk,
         rst_i     => vga_rst,
         rd_addr_o => rd_addr,
         rd_data_i => rd_data,
         palette_i => sw(1 downto 0),
         fps_digits_i => vga_fps_digits,
         fps_blank_i  => vga_fps_blank,
         vga_hs_o  => vga_hs,
         vga_vs_o  => vga_vs,
         vga_col_o => vga_col
      ); -- i_vga


   --------------------------------------------------
   -- Video DAC
   --------------------------------------------------

   -- Expand each colour to 8 bits by repeating the bits, so that the full
   -- range is used (e.g. "111" becomes "11111111"). The outputs are
   -- registered, with one register in the IOB of each output, so that they
   -- all change at the same time.
   p_vdac : process (vga_clk)
   begin
      if rising_edge(vga_clk) then
         vdac_red_r   <= vga_col(7 downto 5) & vga_col(7 downto 5) & vga_col(7 downto 6);
         vdac_green_r <= vga_col(4 downto 2) & vga_col(4 downto 2) & vga_col(4 downto 3);
         vdac_blue_r  <= vga_col(1 downto 0) & vga_col(1 downto 0) & vga_col(1 downto 0) & vga_col(1 downto 0);
         vdac_hs_r    <= vga_hs;
         vdac_vs_r    <= vga_vs;
      end if;
   end process p_vdac;

   vga_red_o   <= vdac_red_r;
   vga_green_o <= vdac_green_r;
   vga_blue_o  <= vdac_blue_r;
   vga_hs_o    <= vdac_hs_r;
   vga_vs_o    <= vdac_vs_r;

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
