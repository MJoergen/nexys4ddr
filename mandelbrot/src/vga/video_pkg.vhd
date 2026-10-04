-- This package defines the VGA video modes, i.e. the screen resolution and the
-- timing of the VGA output signals. Each board selects a video mode in its top
-- level module (nexys4ddr.vhd and mega65_r6.vhd), together with the matching
-- VGA clock (see clk_rst.vhd).
--
-- The timing is from the "VESA MONITOR TIMING STANDARD" (DMT), version 1.0
-- revision 11:
-- http://caxapa.ru/thumbs/361638/DMTv1r11.pdf
-- The times are in pixels (horizontal) and lines (vertical). Each line is
-- the visible pixels, the front porch, the sync pulse, and the back porch, in
-- that order, and the same for each frame.

library ieee;
use ieee.std_logic_1164.all;

package video_pkg is

   type video_mode_t is record
      h_visible   : natural;
      h_front     : natural;
      h_sync      : natural;
      h_back      : natural;
      v_visible   : natural;
      v_front     : natural;
      v_sync      : natural;
      v_back      : natural;
      -- The level of both sync signals during the sync pulse, i.e. '0' for
      -- negative polarity
      sync_active : std_logic;
   end record video_mode_t;

   -- 640x480 @ 60 Hz, pixel clock 25.175 MHz (page 17). It works fine with
   -- 25 MHz.
   constant C_VIDEO_640X480 : video_mode_t := (
      h_visible => 640, h_front => 16, h_sync =>  96, h_back => 48,
      v_visible => 480, v_front => 10, v_sync =>   2, v_back => 33,
      sync_active => '0');

   -- 800x600 @ 60 Hz, pixel clock 40 MHz
   constant C_VIDEO_800X600 : video_mode_t := (
      h_visible => 800, h_front => 40, h_sync => 128, h_back => 88,
      v_visible => 600, v_front =>  1, v_sync =>   4, v_back => 23,
      sync_active => '1');

   -- The total number of pixels in a line, and of lines in a frame
   function h_total (mode : video_mode_t) return natural;
   function v_total (mode : video_mode_t) return natural;

end package video_pkg;

package body video_pkg is

   function h_total (mode : video_mode_t) return natural is
   begin
      return mode.h_visible + mode.h_front + mode.h_sync + mode.h_back;
   end function h_total;

   function v_total (mode : video_mode_t) return natural is
   begin
      return mode.v_visible + mode.v_front + mode.v_sync + mode.v_back;
   end function v_total;

end package body video_pkg;
