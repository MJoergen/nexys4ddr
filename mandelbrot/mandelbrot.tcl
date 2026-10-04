# This is a tcl command script for the Vivado tool chain
# The board name, the FPGA part, the top level module and the VHDL source
# files are given as arguments (-tclargs), so this information is only in the
# Makefile. Use "make nexys4ddr" or "make mega65-r6". The Makefile runs Vivado
# in build/<board>, so the output files (<board>.dcp, <board>.bit, logs, etc.)
# are written there. The constraint file (<board>.xdc) is next to this script.
if {[llength $argv] < 4} {
   puts "ERROR: No board and source files given. Use \"make nexys4ddr\" or \"make mega65-r6\"."
   exit 1
}
lassign $argv board part top
set script_dir [file dirname [file normalize [info script]]]
foreach src [lrange $argv 3 end] {
   read_vhdl -vhdl2008 $src
}
read_xdc [file join $script_dir $board.xdc]
set_param messaging.defaultLimit 3000
synth_design -verbose -top $top -part $part -flatten_hierarchy none -directive AreaOptimized_medium
opt_design -verbose -directive ExploreWithRemap
place_design
phys_opt_design -verbose -directive AlternateFlowWithRetiming
route_design
phys_opt_design -verbose -directive AlternateFlowWithRetiming
write_checkpoint -force $board.dcp
write_bitstream -force $board.bit
exit
