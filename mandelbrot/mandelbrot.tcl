# This is a tcl command script for the Vivado tool chain
# The board name, the FPGA part, the top level module and the VHDL source
# files are given as arguments (-tclargs), so this information is only in the
# Makefile. Use "make nexys4ddr" or "make mega65-r6".
if {[llength $argv] < 4} {
   puts "ERROR: No board and source files given. Use \"make nexys4ddr\" or \"make mega65-r6\"."
   exit 1
}
lassign $argv board part top
foreach src [lrange $argv 3 end] {
   read_vhdl -vhdl2008 $src
}
read_xdc $board.xdc
set_param messaging.defaultLimit 3000
synth_design -verbose -top $top -part $part -flatten_hierarchy none -directive AreaOptimized_medium
# The two DSPs of each iterator are placed next to each other in the same
# column, because the path from each of them to the other one is the longest
# path of the iterator (see iterator.vhd). The relative locations are in DSP
# sites.
set n 0
foreach it [get_cells -hierarchical -filter {NAME =~ *i_iterator}] {
   create_macro iterator_$n
   update_macro iterator_$n [list $it/px_r_reg X0Y0 $it/py_r_reg X0Y1]
   incr n
}
opt_design -verbose -directive ExploreWithRemap
place_design -directive ExtraTimingOpt
phys_opt_design -verbose -directive AlternateFlowWithRetiming
route_design
phys_opt_design -verbose -directive AlternateFlowWithRetiming
write_checkpoint -force $board.dcp
write_bitstream -force $board.bit
exit
