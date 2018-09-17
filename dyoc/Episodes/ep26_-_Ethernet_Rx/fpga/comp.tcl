# This is a tcl command script for the Vivado tool chain

read_vhdl {comp.vhd \
   chipset/ic.vhd chipset/waiter.vhd chipset/timer.vhd \
   vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
   mem/memio.vhd mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
   keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
   cpu/zp.vhd cpu/sr.vhd cpu/regfile.vhd cpu/hilo.vhd cpu/pc.vhd cpu/cycle.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd \
   ethernet/ethernet.vhd ethernet/lan8720a/lan8720a.vhd ethernet/lan8720a/rmii_rx.vhd}
read_xdc comp.xdc

set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]

synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit

source bmm.tcl
exit
