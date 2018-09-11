# This is a tcl command script for the Vivado tool chain
read_vhdl {comp.vhd ic.vhd waiter.vhd timer.vhd\
   vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
   mem/memio.vhd mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
   keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
   cpu/hilo.vhd cpu/pc.vhd cpu/cycle.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd}
read_xdc comp.xdc
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit

source bmm.tcl
exit
