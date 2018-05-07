XILINX_DIR = /opt/Xilinx/Vivado/2017.3

vga.bit: comp.vhd vga/vga.vhd vga/sync.vhd vga/digits.vhd comp.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source comp.tcl"

fpga: vga.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file comp.bit

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf .Xil
	rm -rf .cache
