# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 src/iterator.vhd
read_vhdl -vhdl2008 src/column.vhd
read_vhdl -vhdl2008 src/priority_pipeline.vhd
read_vhdl -vhdl2008 src/priority.vhd
read_vhdl -vhdl2008 src/scheduler.vhd
read_vhdl -vhdl2008 src/dispatcher.vhd
read_vhdl -vhdl2008 src/disp_mem.vhd
read_vhdl -vhdl2008 src/palette_pkg.vhd
read_vhdl -vhdl2008 src/disp.vhd
read_vhdl -vhdl2008 src/pix.vhd
read_vhdl -vhdl2008 src/vga.vhd
read_vhdl -vhdl2008 src/view.vhd
read_vhdl -vhdl2008 src/main.vhd
read_vhdl -vhdl2008 src/clk_rst.vhd
read_vhdl -vhdl2008 src/mandelbrot.vhd
read_xdc mandelbrot.xdc
set_param messaging.defaultLimit 3000
#synth_design -verbose -top mandelbrot -part xc7a100tcsg324-1 -flatten_hierarchy none -keep_equivalent_registers -resource_sharing off
synth_design -verbose -top mandelbrot -part xc7a100tcsg324-1 -flatten_hierarchy none -directive AreaOptimized_medium
#opt_design -verbose -remap -resynth_seq_area -muxf_remap
opt_design -verbose -directive ExploreWithRemap
#power_opt_design -verbose
place_design
phys_opt_design -verbose -directive AlternateFlowWithRetiming
route_design
phys_opt_design -verbose -directive AlternateFlowWithRetiming
write_checkpoint -force mandelbrot.dcp
write_bitstream -force mandelbrot.bit
exit
