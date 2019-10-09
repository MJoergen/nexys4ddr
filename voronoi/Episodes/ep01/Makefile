XILINX_DIR = /opt/Xilinx/Vivado/2019.1

voronoi.bit: voronoi.tcl voronoi.vhd voronoi.xdc vga.vhd dist.vhd minmax.vhd rms.vhd
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: voronoi.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf voronoi.bit
	rm -rf voronoi.dcp
	rm -rf .Xil
	rm -rf .cache

