# This file is specific for the Nexys 4 DDR board.
# See page 7 of the hardware schematic diagram at:
# https://digilent.com/reference/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf

# Pin assignment
set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[7] }];     # VGA_R3
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[6] }];     # VGA_R2
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[5] }];     # VGA_R1
set_property -dict { PACKAGE_PIN A6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[4] }];     # VGA_G3
set_property -dict { PACKAGE_PIN B6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[3] }];     # VGA_G2
set_property -dict { PACKAGE_PIN A5  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[2] }];     # VGA_G1
set_property -dict { PACKAGE_PIN D8  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[1] }];     # VGA_B3
set_property -dict { PACKAGE_PIN D7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[0] }];     # VGA_B2
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { vga_hs_o }];         # VGA_HS
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports { vga_vs_o }];         # VGA_VS
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk_i }];            # CLK100MHZ

set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { sw_i[0] }];          # SW0
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { sw_i[1] }];          # SW1
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { sw_i[2] }];          # SW2
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { sw_i[3] }];          # SW3
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { sw_i[4] }];          # SW4
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { sw_i[5] }];          # SW5
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { sw_i[6] }];          # SW6
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { sw_i[7] }];          # SW7

set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { seg_o[0] }];         # CA
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { seg_o[1] }];         # CB
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { seg_o[2] }];         # CC
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports { seg_o[3] }];         # CD
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { seg_o[4] }];         # CE
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { seg_o[5] }];         # CF
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { seg_o[6] }];         # CG
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { seg_dp_o }];         # DP
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[0] }];      # AN0
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[1] }];      # AN1
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[2] }];      # AN2
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[3] }];      # AN3
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[4] }];      # AN4
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[5] }];      # AN5
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[6] }];      # AN6
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { seg_an_o[7] }];      # AN7

set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { rstn_i }];           # CPU_RESETN

set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { btn_i[0] }];         # BTND
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { btn_i[1] }];         # BTNU
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { btn_i[2] }];         # BTNR
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { btn_i[3] }];         # BTNL
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { btn_i[4] }];         # BTNC

# Clock definition
create_clock -name sys_clk -period 10.00 [get_ports {clk_i}];                          # 100 MHz

# The frame rate is moved from the MAIN clock domain to the VGA clock domain
# with a toggle signal, which is synchronized, see mandelbrot.vhd. These are the
# only paths from the MAIN clock to the VGA clock. Their delay only has to be
# shorter than the synchronizer (two VGA clock cycles), so the relation between
# the two clocks is ignored.
set_max_delay -datapath_only -from [get_clocks -of_objects [get_pins i_clk_rst/mmcm_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins i_clk_rst/mmcm_adv_inst/CLKOUT1]] 10.000

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

