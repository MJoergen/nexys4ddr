# This is a tcl command script for the Vivado tool chain
read_vhdl {vga.vhd digits.vhd}
read_xdc vga.xdc
synth_design -top vga -part xc7a100tcsg324-1
place_design
route_design
write_bitstream vga.bit
