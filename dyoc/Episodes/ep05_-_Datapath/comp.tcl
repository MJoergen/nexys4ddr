# This is a tcl command script for the Vivado tool chain
read_vhdl {comp.vhd clk.vhd waiter.vhd main.vhd \
   vga/font.vhd vga/digits.vhd vga/vga.vhd \
   mem/mem.vhd \
   cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd}
read_xdc comp.xdc
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit
exit
