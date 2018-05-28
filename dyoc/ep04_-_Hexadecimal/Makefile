XILINX_DIR = /opt/Xilinx/Vivado/2017.3

comp.bit: comp.tcl comp.vhd vga/font.vhd vga/digits.vhd vga/vga.vhd mem/mem.vhd comp.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf .cache
