# This file is specific for the Nexys 4 DDR board.

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

set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { sw_i[0] }];          # SW0
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { sw_i[1] }];          # SW1
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { sw_i[2] }];          # SW2
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports { sw_i[3] }];          # SW3
set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports { sw_i[4] }];          # SW4
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { sw_i[5] }];          # SW5
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { sw_i[6] }];          # SW6
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { sw_i[7] }];          # SW7

set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led_o[0] }];         # LED0
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { led_o[1] }];         # LED1
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { led_o[2] }];         # LED2
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { led_o[3] }];         # LED3
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { led_o[4] }];         # LED4
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { led_o[5] }];         # LED5
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { led_o[6] }];         # LED6
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { led_o[7] }];         # LED7

set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports { rstn_i }];           # CPU_RESETN

set_property -dict { PACKAGE_PIN F4  IOSTANDARD LVCMOS33 } [get_ports { ps2_clk_i }];        # PS2_CLK
set_property -dict { PACKAGE_PIN B2  IOSTANDARD LVCMOS33 } [get_ports { ps2_data_i }];       # PS2_DATA

set_property PULLUP TRUE [get_ports { ps2_clk_i } ]
set_property PULLUP TRUE [get_ports { ps2_data_i } ]

# Clock definition
create_clock -name sys_clk -period 10.00 [get_ports {clk_i}];

# CDC
set_false_path -from [get_clocks] -to [get_pins -hierarchical "*gen_cdc.dst_dat_r_reg[*]/D"]

# Configuration Bank Voltage Select
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

