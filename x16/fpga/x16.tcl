# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 { \
   clk.vhd x16.vhd \
   vera/vera.vhd \
   cpu_65c02/cpu_65c02.vhd \
}
read_xdc x16.xdc
synth_design -top x16 -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force x16.dcp
write_bitstream -force x16.bit

#source bmm.tcl
exit
