XILINX_DIR = /opt/Xilinx/Vivado/2018.2

top.bit: top.tcl top.vhd top.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: top.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf top.bit
	rm -rf top.dcp
	rm -rf .Xil
	rm -rf .cache

