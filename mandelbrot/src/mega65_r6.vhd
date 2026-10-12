-- This is the top level module for the MEGA65 (board revision R6). The ports
-- on this entity are mapped directly to pins on the FPGA, see mega65-r6.xdc.
--
-- The design itself is in mega65.vhd, which is the same for the R3 and the
-- R6, see there. This module only connects it to the pins of the R6, and
-- drives the pins that the R3 does not have:
-- * Each joystick line has an output (f[ab]_*_n_o), which pulls the line low
--   when it is low, and leaves it floating when it is high. They must all be
--   driven high, otherwise the joystick lines can be read as pressed: an
--   unused pin has a weak pull-down (the default of Vivado).
-- * The 5V supply of the joysticks can be switched off. It is switched on.
-- * The video DAC has a power save input. It is switched off.
--
-- The design is reset while the reset button (active high) is pressed, and
-- after power-on (while the MMCM is not locked), see clk_rst.vhd.

library ieee;
use ieee.std_logic_1164.all;

entity mega65_r6 is
   port (
      clk_i                 : in  std_logic;               -- 100 MHz
      reset_button_i        : in  std_logic;               -- Active high

      -- Joystick ports, active low
      fa_up_n_i             : in  std_logic;
      fa_down_n_i           : in  std_logic;
      fa_left_n_i           : in  std_logic;
      fa_right_n_i          : in  std_logic;
      fa_fire_n_i           : in  std_logic;
      fb_fire_n_i           : in  std_logic;

      -- MEGA65 keyboard
      kb_io0_o              : out std_logic;
      kb_io1_o              : out std_logic;
      kb_io2_i              : in  std_logic;

      -- Joystick outputs. Low pulls the joystick line low, high leaves it
      -- floating.
      fa_up_n_o             : out std_logic;
      fa_down_n_o           : out std_logic;
      fa_left_n_o           : out std_logic;
      fa_right_n_o          : out std_logic;
      fa_fire_n_o           : out std_logic;
      fb_up_n_o             : out std_logic;
      fb_down_n_o           : out std_logic;
      fb_left_n_o           : out std_logic;
      fb_right_n_o          : out std_logic;
      fb_fire_n_o           : out std_logic;

      -- 5V supply of the joysticks
      joystick_5v_disable_o : out std_logic;               -- Active high

      -- VGA via the video DAC
      vga_red_o             : out std_logic_vector(7 downto 0);
      vga_green_o           : out std_logic_vector(7 downto 0);
      vga_blue_o            : out std_logic_vector(7 downto 0);
      vga_hs_o              : out std_logic;
      vga_vs_o              : out std_logic;
      vdac_clk_o            : out std_logic;
      vdac_sync_n_o         : out std_logic;
      vdac_blank_n_o        : out std_logic;
      vdac_psave_n_o        : out std_logic
   );
end mega65_r6;

architecture structural of mega65_r6 is

   signal rstn : std_logic;

begin

   rstn <= not reset_button_i;

   i_mega65 : entity work.mega65
      port map (
         clk_i          => clk_i,
         rstn_i         => rstn,
         fa_up_n_i      => fa_up_n_i,
         fa_down_n_i    => fa_down_n_i,
         fa_left_n_i    => fa_left_n_i,
         fa_right_n_i   => fa_right_n_i,
         fa_fire_n_i    => fa_fire_n_i,
         fb_fire_n_i    => fb_fire_n_i,
         kb_io0_o       => kb_io0_o,
         kb_io1_o       => kb_io1_o,
         kb_io2_i       => kb_io2_i,
         vga_red_o      => vga_red_o,
         vga_green_o    => vga_green_o,
         vga_blue_o     => vga_blue_o,
         vga_hs_o       => vga_hs_o,
         vga_vs_o       => vga_vs_o,
         vdac_clk_o     => vdac_clk_o,
         vdac_sync_n_o  => vdac_sync_n_o,
         vdac_blank_n_o => vdac_blank_n_o
      ); -- i_mega65

   -- The joysticks are only read
   fa_up_n_o    <= '1';
   fa_down_n_o  <= '1';
   fa_left_n_o  <= '1';
   fa_right_n_o <= '1';
   fa_fire_n_o  <= '1';
   fb_up_n_o    <= '1';
   fb_down_n_o  <= '1';
   fb_left_n_o  <= '1';
   fb_right_n_o <= '1';
   fb_fire_n_o  <= '1';

   joystick_5v_disable_o <= '0';  -- Power on
   vdac_psave_n_o        <= '1';  -- Power on

end architecture structural;
