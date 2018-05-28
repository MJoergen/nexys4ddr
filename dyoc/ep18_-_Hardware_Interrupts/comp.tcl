# This is a tcl command script for the Vivado tool chain
read_vhdl {comp.vhd \
   vga/font.vhd vga/digits.vhd vga/vga.vhd \
   mem/cic.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
   cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd}
read_xdc comp.xdc
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit
exit
