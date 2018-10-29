XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = comp.vhd clk.vhd waiter.vhd main.vhd \
		 vga/vga.vhd vga/digits.vhd vga/font.vhd \
		 cpu/cpu.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/alu.vhd \
		 mem/mem.vhd
XDC  = comp.xdc
TB   = tb.vhd
WAVE = tb.ghw
SAVE = tb.gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC)
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

sim: $(SRC) $(TB)
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=$(WAVE) --stop-time=40us
	gtkwave $(WAVE) $(SAVE)


clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf *.o
	rm -rf work-obj93.cf
	rm -rf tb
	rm -rf tb.ghw
