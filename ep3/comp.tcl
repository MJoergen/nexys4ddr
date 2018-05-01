# This is a tcl command script for the Vivado tool chain
read_vhdl {comp.vhd vga/sync.vhd vga/digits.vhd vga/vga.vhd mem/mem.vhd cpu/cpu.vhd}
read_xdc comp.xdc
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_bitstream comp.bit

# The following line is optional
write_checkpoint comp.dcp

start_gui
