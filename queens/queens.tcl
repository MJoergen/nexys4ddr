# This is a tcl command script for the Vivado tool chain
#read_vhdl -vhdl2008 { \

read_vhdl { \
   src/counter.vhd \
   src/clk_wiz_0.vhd \
   src/clk_wiz_0_clk_wiz.vhd \
   src/vga_bitmap_pkg.vhd \
   src/vga_disp_queens.vhd \
   src/vga_ctrl.vhd \
   src/vga.vhd \
   src/display_digit.vhd \
   src/display_int2seg.vhd \
   src/display_seg.vhd \
   src/display.vhd \
   src/queens.vhd \
   src/queens_top.vhd
}
read_xdc src/queens_top.xdc
synth_design -top queens_top -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force queens.dcp
write_bitstream -force queens.bit
exit


