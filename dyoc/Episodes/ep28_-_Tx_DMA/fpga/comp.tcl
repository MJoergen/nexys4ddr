# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 { \
   comp.vhd waiter.vhd clk.vhd cdc.vhd cdc_pulse.vhd \
   vga/vga.vhd vga/overlay.vhd vga/pix.vhd vga/font.vhd vga/opcodes.vhd vga/chars.vhd \
   keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
   ethernet/ethernet.vhd ethernet/lan8720a/lan8720a.vhd ethernet/lan8720a/rmii_rx.vhd ethernet/lan8720a/rmii_tx.vhd \
   ethernet/rx_dma.vhd ethernet/fifo.vhd ethernet/rx_header.vhd ethernet/tx_dma.vhd \
   main/main.vhd main/ic.vhd main/timer.vhd \
   main/cpu/cpu.vhd main/cpu/datapath.vhd main/cpu/ctl.vhd main/cpu/pc.vhd main/cpu/ar.vhd main/cpu/hi.vhd main/cpu/lo.vhd main/cpu/alu.vhd main/cpu/sr.vhd main/cpu/sp.vhd main/cpu/xr.vhd main/cpu/yr.vhd main/cpu/zp.vhd \
   main/mem/mem.vhd main/mem/rom.vhd main/mem/ram.vhd main/mem/dmem.vhd main/mem/memio.vhd \
}
read_xdc comp.xdc
set_property XPM_LIBRARIES {XPM_FIFO} [current_project]
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit
report_methodology
report_timing_summary -file timing_summary.rpt
source bmm.tcl
exit
