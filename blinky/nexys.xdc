########################
# Pin locations
########################

## Clock signal
set_property LOC E3 [get_ports clk_i]

## Switches
set_property LOC J15 [get_ports sw_i[0] ]
set_property LOC L16 [get_ports sw_i[1] ]
set_property LOC M13 [get_ports sw_i[2] ]
set_property LOC R15 [get_ports sw_i[3] ]
set_property LOC R17 [get_ports sw_i[4] ]
set_property LOC T18 [get_ports sw_i[5] ]
set_property LOC U18 [get_ports sw_i[6] ]
set_property LOC R13 [get_ports sw_i[7] ]

## LEDs
set_property LOC H17 [get_ports led_o[0] ]
set_property LOC K15 [get_ports led_o[1] ]
set_property LOC J13 [get_ports led_o[2] ]
set_property LOC N14 [get_ports led_o[3] ]
set_property LOC R18 [get_ports led_o[4] ]
set_property LOC V17 [get_ports led_o[5] ]
set_property LOC U17 [get_ports led_o[6] ]
set_property LOC U16 [get_ports led_o[7] ]

##7 segment displ
set_property LOC T10 [get_ports seg_ca_o[0] ]
set_property LOC R10 [get_ports seg_ca_o[1] ]
set_property LOC K16 [get_ports seg_ca_o[2] ]
set_property LOC K13 [get_ports seg_ca_o[3] ]
set_property LOC P15 [get_ports seg_ca_o[4] ]
set_property LOC T11 [get_ports seg_ca_o[5] ]
set_property LOC L18 [get_ports seg_ca_o[6] ]
set_property LOC H15 [get_ports seg_dp_o ]
set_property LOC J17 [get_ports seg_an_o[0] ]
set_property LOC J18 [get_ports seg_an_o[1] ]
set_property LOC T9  [get_ports seg_an_o[2] ]
set_property LOC J14 [get_ports seg_an_o[3] ]

#VGA Connector
set_property LOC A3  [get_ports vga_red_o[0] ]
set_property LOC B4  [get_ports vga_red_o[1] ]
set_property LOC C5  [get_ports vga_red_o[2] ]
set_property LOC A4  [get_ports vga_red_o[3] ]
set_property LOC C6  [get_ports vga_green_o[0] ]
set_property LOC A5  [get_ports vga_green_o[1] ]
set_property LOC B6  [get_ports vga_green_o[2] ]
set_property LOC A6  [get_ports vga_green_o[3] ]
set_property LOC B7  [get_ports vga_blue_o[0] ]
set_property LOC C7  [get_ports vga_blue_o[1] ]
set_property LOC D7  [get_ports vga_blue_o[2] ]
set_property LOC D8  [get_ports vga_blue_o[3] ]
set_property LOC B11 [get_ports vga_hs_o ]
set_property LOC B12 [get_ports vga_vs_o ]


########################
## I/O standards
########################

# Clock signal
set_property IOSTANDARD LVCMOS33 [get_ports clk_i ]

## Switches
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[3] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[4] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[5] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[6] ]
set_property IOSTANDARD LVCMOS33 [get_ports sw_i[7] ]

## LEDs
set_property IOSTANDARD LVCMOS33 [get_ports led_o[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[3] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[4] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[5] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[6] ]
set_property IOSTANDARD LVCMOS33 [get_ports led_o[7] ]

##7 segment d
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[3] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[4] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[5] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_ca_o[6] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_dp_o ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_an_o[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_an_o[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_an_o[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports seg_an_o[3] ]

#VGA Connecto
set_property IOSTANDARD LVCMOS33 [get_ports vga_red_o[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_red_o[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_red_o[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_red_o[3] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_green_o[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_green_o[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_green_o[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_green_o[3] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_blue_o[0] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_blue_o[1] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_blue_o[2] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_blue_o[3] ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hs_o ]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vs_o ]

#set_property CFGBVS VCCO [current_design]
#set_property CONFIG_VOLTAGE 3.3 [current_design]

########################
# Timing constraints
########################
create_clock -add -name sys_clk_pin -period 10.00 [get_ports clk_i]

