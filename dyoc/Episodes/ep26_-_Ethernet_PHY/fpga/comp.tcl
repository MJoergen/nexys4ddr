# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 { \
   chipset/ic.vhd chipset/waiter.vhd chipset/timer.vhd \
   vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
   keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
   main/mem/dmem.vhd main/mem/ram.vhd main/mem/rom.vhd main/mem/mem.vhd main/mem/memio.vhd \
   main/cpu/zp.vhd main/cpu/sr.vhd main/cpu/regfile.vhd main/cpu/hilo.vhd main/cpu/pc.vhd main/cpu/datapath.vhd main/cpu/ctl.vhd main/cpu/cpu.vhd main/cpu/alu.vhd main/cpu/cycle.vhd \
   ethernet/ethernet.vhd ethernet/lan8720a/lan8720a.vhd ethernet/lan8720a/rmii_rx.vhd ethernet/lan8720a/rmii_tx.vhd \
   comp.vhd}
read_xdc comp.xdc
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit

source bmm.tcl
exit
