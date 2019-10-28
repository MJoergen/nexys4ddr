XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SOURCES  = x16.tcl x16.vhd x16.xdc clk.vhd
SOURCES += vera/vera.vhd vera/pix.vhd vera/vga.vhd vera/vram.vhd vera/palette.vhd vera/mode0.vhd vera/cpu.vhd
SOURCES += cpu_65c02/cpu_65c02.vhd
  
x16.bit: $(SOURCES)
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: x16.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf x16.bit
	rm -rf x16.dcp
	rm -rf .Xil
	rm -rf .cache


