# Builds the bit-file from the Vivado project, without the GUI.
# Run from the queens directory with:
#   vivado -mode batch -source vivado/build.tcl -tclargs <jobs>

set jobs [expr {$argc > 0 ? [lindex $argv 0] : 4}]

open_project vivado/vivado.xpr

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
   error "Implementation failed. See vivado/vivado.runs/impl_1/runme.log"
}

set bitfile [get_property DIRECTORY [get_runs impl_1]]/queens_top.bit
file copy -force $bitfile queens_vivado.bit
puts "Wrote queens_vivado.bit"

close_project
