# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 { top.vhd debug.vhd \
   vga/vga.vhd vga/pix.vhd vga/rom.vhd }
read_xdc top.xdc
synth_design -top top -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force top.dcp
write_bitstream -force top.bit
exit
