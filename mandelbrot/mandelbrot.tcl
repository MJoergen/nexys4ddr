# This is a tcl command script for the Vivado tool chain
# The VHDL source files are given as arguments (-tclargs), so the list of
# source files is only in the Makefile (SRC). Use "make nexys4ddr".
if {[llength $argv] == 0} {
   puts "ERROR: No source files given. Use \"make nexys4ddr\"."
   exit 1
}
foreach src $argv {
   read_vhdl -vhdl2008 $src
}
read_xdc nexys4ddr.xdc
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
write_bitstream -force nexys4ddr.bit
exit
