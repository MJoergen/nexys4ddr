all:
	source /opt/Xilinx/Vivado/2017.3/settings64.sh ; vivado -mode tcl -source vga.tcl
	djtgcfg prog -d Nexys4DDR -i 0 --file vga.bit
