XILINX_DIR = /opt/Xilinx/Vivado/2017.3


MAIN = main.vhd \
		 cpu/cpu.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/pc.vhd cpu/ar.vhd cpu/hi.vhd cpu/lo.vhd cpu/alu.vhd cpu/sr.vhd \
		 mem/mem.vhd
SRC  = $(MAIN) \
		 comp.vhd waiter.vhd clk.vhd \
		 vga/vga.vhd vga/digits.vhd vga/pix.vhd vga/font.vhd
XDC  = comp.xdc
TB   = main_tb.vhd
WAVE = main_tb.ghw
SAVE = main_tb.gtkw


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

sim: $(MAIN) $(TB)
	ghdl -i --work=work $(MAIN) $(TB)
	ghdl -m --ieee=synopsys -fexplicit main_tb
	ghdl -r main_tb --assert-level=error --wave=$(WAVE) --stop-time=20us
	gtkwave $(WAVE) $(SAVE)


clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf timing_summary.rpt
	rm -rf .cache
	rm -rf *.o
	rm -rf work-obj93.cf
	rm -rf main_tb
	rm -rf main_tb.ghw

