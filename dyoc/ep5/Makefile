XILINX_DIR = /opt/Xilinx/Vivado/2017.3

comp.bit: comp.vhd vga/sync.vhd vga/digits.vhd vga/vga.vhd mem/mem.vhd cpu/cpu.vhd cpu/ctl.vhd comp.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source comp.tcl"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file comp.bit

sim:
	ghdl -i --work=work cpu/cpu.vhd cpu/ctl.vhd mem/mem.vhd tb.vhd
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=tb.ghw

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf .Xil
	rm -rf .cache
	rm -rf tb.ghw
	rm -rf *.o
	rm -rf work-obj93.cf
	rm -rf tb
