XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SOURCES  = x16.vhd
SOURCES += clk.vhd
SOURCES += vera/vera.vhd
SOURCES += vera/pix.vhd
SOURCES += vera/vga.vhd
SOURCES += vera/vram.vhd
SOURCES += vera/palette.vhd
SOURCES += vera/mode0.vhd
SOURCES += vera/cpu.vhd
SOURCES += cpu_65c02/cpu_65c02.vhd
  
x16.bit: x16.tcl $(SOURCES) x16.xdc Makefile
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

x16.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(SOURCES)  }" >> $@
	echo "read_xdc x16.xdc" >> $@
	echo "synth_design -top x16 -part xc7a100tcsg324-1 -flatten_hierarchy none" >> $@
	echo "place_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force x16.dcp" >> $@
	echo "write_bitstream -force x16.bit" >> $@
	echo "exit" >> $@

fpga: x16.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf x16.bit
	rm -rf x16.dcp
	rm -rf x16.tcl
	rm -rf .Xil
	rm -rf .cache


