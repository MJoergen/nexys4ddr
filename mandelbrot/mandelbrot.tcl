# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 src/mandelbrot.vhd
read_xdc mandelbrot.xdc
synth_design -top mandelbrot -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force mandelbrot.dcp
write_bitstream -force mandelbrot.bit
exit
