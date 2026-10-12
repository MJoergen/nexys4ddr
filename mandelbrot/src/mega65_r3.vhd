-- This is the top level module for the MEGA65 (board revision R3). The ports
-- on this entity are mapped directly to pins on the FPGA, see mega65-r3.xdc.
--
-- The design itself is in mega65.vhd, which is the same for the R3 and the
-- R6, see there. This module only connects it to the pins of the R3, and
-- drives the pins of the HDMI level shifter (U10 = TPD12S016), which are
-- different on the R6: The +5V supply of the HDMI connector (CT_HPD) and the
-- output enable of the level shifter (LS_OE, active high) are switched on, as
-- in the MiSTer2MEGA65 framework.
--
-- On the R3 the reset button is not connected to the FPGA. It is read by the
-- MAX10 (a small FPGA on the board), which sends it to the FPGA over a serial
-- link, together with other signals. This is not implemented, so the design
-- is only reset while the MMCM is not locked, i.e. after power-on.
--
-- Do not use this design on a later board revision, see mega65_r6.vhd.

library ieee;
use ieee.std_logic_1164.all;

entity mega65_r3 is
   port (
      clk_i          : in  std_logic;                      -- 100 MHz

      -- Joystick ports, active low
      fa_up_n_i      : in  std_logic;
      fa_down_n_i    : in  std_logic;
      fa_left_n_i    : in  std_logic;
      fa_right_n_i   : in  std_logic;
      fa_fire_n_i    : in  std_logic;
      fb_fire_n_i    : in  std_logic;

      -- MEGA65 keyboard
      kb_io0_o       : out std_logic;
      kb_io1_o       : out std_logic;
      kb_io2_i       : in  std_logic;

      -- VGA via the video DAC
      vga_red_o      : out std_logic_vector(7 downto 0);
      vga_green_o    : out std_logic_vector(7 downto 0);
      vga_blue_o     : out std_logic_vector(7 downto 0);
      vga_hs_o       : out std_logic;
      vga_vs_o       : out std_logic;
      vdac_clk_o     : out std_logic;
      vdac_sync_n_o  : out std_logic;
      vdac_blank_n_o : out std_logic;

      -- HDMI
      tmds_data_p_o  : out std_logic_vector(2 downto 0);
      tmds_data_n_o  : out std_logic_vector(2 downto 0);
      tmds_clk_p_o   : out std_logic;
      tmds_clk_n_o   : out std_logic;
      hdmi_ct_hpd_o  : out std_logic;
      hdmi_ls_oe_o   : out std_logic
   );
end mega65_r3;

architecture structural of mega65_r3 is

begin

   i_mega65 : entity work.mega65
      port map (
         clk_i          => clk_i,
         rstn_i         => '1',
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
         vdac_blank_n_o => vdac_blank_n_o,
         tmds_data_p_o  => tmds_data_p_o,
         tmds_data_n_o  => tmds_data_n_o,
         tmds_clk_p_o   => tmds_clk_p_o,
         tmds_clk_n_o   => tmds_clk_n_o
      ); -- i_mega65

   hdmi_ct_hpd_o  <= '1';  -- Supply +5V to the HDMI connector
   hdmi_ls_oe_o   <= '1';  -- Enable the HDMI level shifter

end architecture structural;
