# This is a tcl command script for the Vivado tool chain
read_vhdl -vhdl2008 { \
   voronoi.vhd vga.vhd \
   dist.vhd minmax.vhd rms.vhd
}
read_xdc voronoi.xdc
synth_design -top voronoi -part xc7a100tcsg324-1 -flatten_hierarchy none
place_design
route_design
write_checkpoint -force voronoi.dcp
write_bitstream -force voronoi.bit
exit
