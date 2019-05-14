# This file is specific for the Nexys 4 DDR board.
# See page 7 of the hardware schematic diagram at:
# https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf

# Pin assignment
set_property -dict { PACKAGE_PIN A4  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[11] }];    # VGA_R3
set_property -dict { PACKAGE_PIN C5  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[10] }];    # VGA_R2
set_property -dict { PACKAGE_PIN B4  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[9] }];     # VGA_R1
set_property -dict { PACKAGE_PIN A3  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[8] }];     # VGA_R0
set_property -dict { PACKAGE_PIN A6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[7] }];     # VGA_G3
set_property -dict { PACKAGE_PIN B6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[6] }];     # VGA_G2
set_property -dict { PACKAGE_PIN A5  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[5] }];     # VGA_G1
set_property -dict { PACKAGE_PIN C6  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[4] }];     # VGA_G0
set_property -dict { PACKAGE_PIN D8  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[3] }];     # VGA_B3
set_property -dict { PACKAGE_PIN D7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[2] }];     # VGA_B2
set_property -dict { PACKAGE_PIN C7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[1] }];     # VGA_B1
set_property -dict { PACKAGE_PIN B7  IOSTANDARD LVCMOS33 } [get_ports { vga_col_o[0] }];     # VGA_B0
set_property -dict { PACKAGE_PIN B11 IOSTANDARD LVCMOS33 } [get_ports { vga_hs_o }];         # VGA_HS
set_property -dict { PACKAGE_PIN B12 IOSTANDARD LVCMOS33 } [get_ports { vga_vs_o }];         # VGA_VS
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk_i }];            # CLK100MHZ

# Clock definition
create_clock -name sys_clk -period 10.00 [get_ports {clk_i}];                          # 100 MHz
create_generated_clock -name vga_clk -source [get_ports {clk_i}] -divide_by 4 [get_pins {clk_cnt_reg[1]/Q}];   # 25 Mhz

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

