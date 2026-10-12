# This file is specific for the MEGA65 (board revision R6).
# It contains only the pins used by this design, taken from the MiSTer2MEGA
# framework pin mapping (MEGA65-R6.xdc) by MJoergen and sy2002.

# Pin assignment
set_property -dict {PACKAGE_PIN V13  IOSTANDARD LVCMOS33} [get_ports {clk_i}];                  # CLOCK_FPGA_MRCC
set_property -dict {PACKAGE_PIN J19  IOSTANDARD LVCMOS33} [get_ports {reset_button_i}];         # RESET

# Joystick
set_property -dict {PACKAGE_PIN F16  IOSTANDARD LVCMOS33} [get_ports {fa_down_n_i}];            # FA_DOWN
set_property -dict {PACKAGE_PIN E17  IOSTANDARD LVCMOS33} [get_ports {fa_fire_n_i}];            # FA_FIRE
set_property -dict {PACKAGE_PIN F14  IOSTANDARD LVCMOS33} [get_ports {fa_left_n_i}];            # FA_LEFT
set_property -dict {PACKAGE_PIN F13  IOSTANDARD LVCMOS33} [get_ports {fa_right_n_i}];           # FA_RIGHT
set_property -dict {PACKAGE_PIN C14  IOSTANDARD LVCMOS33} [get_ports {fa_up_n_i}];              # FA_UP
set_property -dict {PACKAGE_PIN F15  IOSTANDARD LVCMOS33} [get_ports {fb_fire_n_i}];            # FB_FIRE

# Joystick outputs, which pull the joystick lines low (not on the R3)
set_property -dict {PACKAGE_PIN J17  IOSTANDARD LVCMOS33} [get_ports {fa_fire_n_o}];            # DBG0 = FA_FIRE_O
set_property -dict {PACKAGE_PIN G16  IOSTANDARD LVCMOS33} [get_ports {fa_up_n_o}];              # DBG1 = FA_UP_O
set_property -dict {PACKAGE_PIN K13  IOSTANDARD LVCMOS33} [get_ports {fa_left_n_o}];            # DBG2 = FA_LEFT_O
set_property -dict {PACKAGE_PIN K14  IOSTANDARD LVCMOS33} [get_ports {fa_down_n_o}];            # DBG3 = FA_DOWN_O
set_property -dict {PACKAGE_PIN N20  IOSTANDARD LVCMOS33} [get_ports {fb_up_n_o}];              # DBG4 = FB_UP_O
set_property -dict {PACKAGE_PIN L16  IOSTANDARD LVCMOS33} [get_ports {fa_right_n_o}];           # DBG5 = FA_RIGHT_O
set_property -dict {PACKAGE_PIN M18  IOSTANDARD LVCMOS33} [get_ports {fb_down_n_o}];            # DBG6 = FB_DOWN_O
set_property -dict {PACKAGE_PIN N19  IOSTANDARD LVCMOS33} [get_ports {fb_fire_n_o}];            # DBG7 = FB_FIRE_O
set_property -dict {PACKAGE_PIN E18  IOSTANDARD LVCMOS33} [get_ports {fb_right_n_o}];           # DBG8 = FB_RIGHT_O
set_property -dict {PACKAGE_PIN M17  IOSTANDARD LVCMOS33} [get_ports {fb_left_n_o}];            # DBG9 = FB_LEFT_O

# Joystick power supply (not on the R3)
set_property -dict {PACKAGE_PIN D19  IOSTANDARD LVCMOS33} [get_ports {joystick_5v_disable_o}];  # EN_5V_JOY_N

# MEGA65 Keyboard
set_property -dict {PACKAGE_PIN A14  IOSTANDARD LVCMOS33} [get_ports {kb_io0_o}];               # KB_IO1
set_property -dict {PACKAGE_PIN A13  IOSTANDARD LVCMOS33} [get_ports {kb_io1_o}];               # KB_IO2
set_property -dict {PACKAGE_PIN C13  IOSTANDARD LVCMOS33} [get_ports {kb_io2_i}];               # KB_IO3

# VGA via VDAC. U3 = ADV7125BCPZ170
set_property -dict {PACKAGE_PIN W11  IOSTANDARD LVCMOS33} [get_ports {vdac_blank_n_o}];         # VDAC_BLANK_N
set_property -dict {PACKAGE_PIN AA9  IOSTANDARD LVCMOS33} [get_ports {vdac_clk_o}];             # VDAC_CLK
set_property -dict {PACKAGE_PIN W16  IOSTANDARD LVCMOS33} [get_ports {vdac_psave_n_o}];         # VDAC_PSAVE_N
set_property -dict {PACKAGE_PIN V10  IOSTANDARD LVCMOS33} [get_ports {vdac_sync_n_o}];          # VDAC_SYNC_N
set_property -dict {PACKAGE_PIN W10  IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[0]}];          # B0
set_property -dict {PACKAGE_PIN Y12  IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[1]}];          # B1
set_property -dict {PACKAGE_PIN AB12 IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[2]}];          # B2
set_property -dict {PACKAGE_PIN AA11 IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[3]}];          # B3
set_property -dict {PACKAGE_PIN AB11 IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[4]}];          # B4
set_property -dict {PACKAGE_PIN Y11  IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[5]}];          # B5
set_property -dict {PACKAGE_PIN AB10 IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[6]}];          # B6
set_property -dict {PACKAGE_PIN AA10 IOSTANDARD LVCMOS33} [get_ports {vga_blue_o[7]}];          # B7
set_property -dict {PACKAGE_PIN Y14  IOSTANDARD LVCMOS33} [get_ports {vga_green_o[0]}];         # G0
set_property -dict {PACKAGE_PIN W14  IOSTANDARD LVCMOS33} [get_ports {vga_green_o[1]}];         # G1
set_property -dict {PACKAGE_PIN AA15 IOSTANDARD LVCMOS33} [get_ports {vga_green_o[2]}];         # G2
set_property -dict {PACKAGE_PIN AB15 IOSTANDARD LVCMOS33} [get_ports {vga_green_o[3]}];         # G3
set_property -dict {PACKAGE_PIN Y13  IOSTANDARD LVCMOS33} [get_ports {vga_green_o[4]}];         # G4
set_property -dict {PACKAGE_PIN AA14 IOSTANDARD LVCMOS33} [get_ports {vga_green_o[5]}];         # G5
set_property -dict {PACKAGE_PIN AA13 IOSTANDARD LVCMOS33} [get_ports {vga_green_o[6]}];         # G6
set_property -dict {PACKAGE_PIN AB13 IOSTANDARD LVCMOS33} [get_ports {vga_green_o[7]}];         # G7
set_property -dict {PACKAGE_PIN W12  IOSTANDARD LVCMOS33} [get_ports {vga_hs_o}];               # HSYNC
set_property -dict {PACKAGE_PIN U15  IOSTANDARD LVCMOS33} [get_ports {vga_red_o[0]}];           # R0
set_property -dict {PACKAGE_PIN V15  IOSTANDARD LVCMOS33} [get_ports {vga_red_o[1]}];           # R1
set_property -dict {PACKAGE_PIN T14  IOSTANDARD LVCMOS33} [get_ports {vga_red_o[2]}];           # R2
set_property -dict {PACKAGE_PIN Y17  IOSTANDARD LVCMOS33} [get_ports {vga_red_o[3]}];           # R3
set_property -dict {PACKAGE_PIN Y16  IOSTANDARD LVCMOS33} [get_ports {vga_red_o[4]}];           # R4
set_property -dict {PACKAGE_PIN AB17 IOSTANDARD LVCMOS33} [get_ports {vga_red_o[5]}];           # R5
set_property -dict {PACKAGE_PIN AA16 IOSTANDARD LVCMOS33} [get_ports {vga_red_o[6]}];           # R6
set_property -dict {PACKAGE_PIN AB16 IOSTANDARD LVCMOS33} [get_ports {vga_red_o[7]}];           # R7
set_property -dict {PACKAGE_PIN V14  IOSTANDARD LVCMOS33} [get_ports {vga_vs_o}];               # VSYNC

# HDMI output. U10 = PTN3363BSMP
set_property -dict {PACKAGE_PIN Y1   IOSTANDARD TMDS_33}  [get_ports {tmds_clk_n_o}];           # TXC_N
set_property -dict {PACKAGE_PIN W1   IOSTANDARD TMDS_33}  [get_ports {tmds_clk_p_o}];           # TXC_P
set_property -dict {PACKAGE_PIN AB1  IOSTANDARD TMDS_33}  [get_ports {tmds_data_n_o[0]}];       # TX0_N
set_property -dict {PACKAGE_PIN AB2  IOSTANDARD TMDS_33}  [get_ports {tmds_data_n_o[1]}];       # TX1_N
set_property -dict {PACKAGE_PIN AB5  IOSTANDARD TMDS_33}  [get_ports {tmds_data_n_o[2]}];       # TX2_N
set_property -dict {PACKAGE_PIN AA1  IOSTANDARD TMDS_33}  [get_ports {tmds_data_p_o[0]}];       # TX0_P
set_property -dict {PACKAGE_PIN AB3  IOSTANDARD TMDS_33}  [get_ports {tmds_data_p_o[1]}];       # TX1_P
set_property -dict {PACKAGE_PIN AA5  IOSTANDARD TMDS_33}  [get_ports {tmds_data_p_o[2]}];       # TX2_P
set_property -dict {PACKAGE_PIN M15  IOSTANDARD LVCMOS33} [get_ports {hdmi_hiz_en_o}];          # HIZ_EN
set_property -dict {PACKAGE_PIN AB8  IOSTANDARD LVCMOS33} [get_ports {hdmi_ls_oe_n_o}];         # LS_OE

# Clock definition
create_clock -name sys_clk -period 10.00 [get_ports {clk_i}];                          # 100 MHz

# The frame rate is moved from the MAIN clock domain to the VGA clock domain
# with a toggle signal, which is synchronized, see mega65.vhd. These are the
# only paths from the MAIN clock to the VGA clock. Their delay only has to be
# shorter than the synchronizer (two VGA clock cycles), so the relation between
# the two clocks is ignored.
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins i_mega65/i_clk_rst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins i_mega65/i_clk_rst/mmcm_adv_inst/CLKOUT1]] 10.000

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
