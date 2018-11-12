# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 { \
   chipset/ic.vhd chipset/waiter.vhd chipset/timer.vhd \
   vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
   mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd mem/memio.vhd \
   keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
   cpu/zp.vhd cpu/sr.vhd cpu/regfile.vhd cpu/hilo.vhd cpu/pc.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd cpu/cycle.vhd \
   comp.vhd}
read_xdc comp.xdc
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit

source bmm.tcl
exit
