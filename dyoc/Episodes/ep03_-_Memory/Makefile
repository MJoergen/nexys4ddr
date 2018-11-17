XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC = comp.vhd waiter.vhd \
		vga/vga.vhd vga/digits.vhd vga/pix.vhd \
		mem/mem.vhd
XDC = comp.xdc

#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC)
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

