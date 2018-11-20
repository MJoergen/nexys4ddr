XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC = comp.vhd waiter.vhd clk.vhd cdc.vhd \
		vga/vga.vhd vga/digits.vhd vga/pix.vhd vga/font.vhd vga/opcodes.vhd \
		main/main.vhd \
		main/cpu/cpu.vhd main/cpu/datapath.vhd main/cpu/ctl.vhd main/cpu/pc.vhd main/cpu/ar.vhd main/cpu/hi.vhd main/cpu/lo.vhd main/cpu/alu.vhd main/cpu/sr.vhd \
		main/mem/ram.vhd
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
	rm -rf timing_summary.rpt
	rm -rf .cache

