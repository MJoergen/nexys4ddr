library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std_unsigned.all;

library unisim;
use unisim.vcomponents.all;

-- This is the top level module for the MEGA65 (board revision R6). The ports
-- on this entity are mapped directly to pins on the FPGA, see mega65-r6.xdc.
--
-- It is the same design as mandelbrot.vhd (the top level module for the
-- Nexys 4 DDR board), only the ports are different:
-- * There are no buttons and switches. Instead, the view is controlled by the
--   joysticks: The directions of joystick port A pan the view, and the fire
--   button of port A zooms in. The fire button of port B zooms out.
-- * The palette can not be selected, so palette 0 is always used.
-- * There is no 7-segment display, so the frame rate is not shown.
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

   signal rstn           : std_logic;
   signal btn            : std_logic_vector( 4 downto 0);  -- "CLRUD"
   signal sw             : std_logic_vector( 7 downto 0);

   signal main_clk       : std_logic;
   signal main_rst       : std_logic;

   signal vga_clk        : std_logic;
   signal vga_rst        : std_logic;

   signal wr_addr        : std_logic_vector(18 downto 0);
   signal wr_data        : std_logic_vector( 8 downto 0);
   signal wr_en          : std_logic;

   signal rd_addr        : std_logic_vector(18 downto 0);
   signal rd_data        : std_logic_vector( 8 downto 0);

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
      port map (
         clk_i     => main_clk,
         rst_i     => main_rst,
         btn_i     => btn,
         sw_i      => sw,
         seg_o     => open,
         seg_an_o  => open,
         wr_addr_o => wr_addr,
         wr_data_o => wr_data,
         wr_en_o   => wr_en
      ); -- i_main


   ------------------------------
   -- Instantiate display memory
   ------------------------------

   i_disp_mem : entity work.disp_mem
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
   -- Instantiate VGA clock domain
   --------------------------------------------------

   i_vga : entity work.vga
      port map (
         clk_i     => vga_clk,
         rst_i     => vga_rst,
         rd_addr_o => rd_addr,
         rd_data_i => rd_data,
         palette_i => sw(4 downto 3),
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
