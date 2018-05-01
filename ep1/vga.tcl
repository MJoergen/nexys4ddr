
read_vhdl {
   vga.vhd
}
read_xdc vga.xdc
synth_design -top vga -part xc7a100tcsg324-1
opt_design 
place_design
route_design
write_bitstream -force vga.bit
exit
