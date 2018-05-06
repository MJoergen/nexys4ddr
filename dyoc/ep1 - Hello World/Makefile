XILINX_DIR = /opt/Xilinx/Vivado/2017.3

vga.bit: vga.vhd vga.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source vga.tcl"

fpga: vga.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file vga.bit

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf vga.bit
	rm -rf .Xil
	rm -rf .cache
