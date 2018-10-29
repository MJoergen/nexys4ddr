# This is a tcl command script for the Vivado tool chain
read_vhdl { \
   comp.vhd clk.vhd waiter.vhd main.vhd \
   vga/font.vhd vga/digits.vhd vga/vga.vhd \
   mem/mem.vhd
}
read_xdc comp.xdc
set_property XPM_LIBRARIES {XPM_CDC} [current_project]
synth_design -top comp -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force comp.dcp
write_bitstream -force comp.bit
report_methodology
report_timing_summary -file timing_summary.rpt
exit
