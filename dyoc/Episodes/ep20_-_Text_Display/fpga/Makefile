XILINX_DIR = /opt/Xilinx/Vivado/2017.3

MAIN = main.vhd \
		 cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd \
		 mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd
SRC  = $(MAIN) \
		 comp.vhd clk.vhd waiter.vhd \
		 vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd
XDC  = comp.xdc
TB   = main_tb.vhd
WAVE = main_tb.ghw
SAVE = main_tb.gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC) ../rom.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

sim: $(MAIN) $(TB) ../rom.txt
	ghdl -i --work=work $(MAIN) $(TB)
	ghdl -m --ieee=synopsys -fexplicit main_tb
	ghdl -r main_tb --assert-level=error --wave=$(WAVE) --stop-time=400us
	gtkwave $(WAVE) $(SAVE)


#####################################
# Cleanup
#####################################

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf *.o
	rm -rf comp.bit
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf timing_summary.rpt
	rm -rf .cache
	rm -rf work-obj93.cf
	rm -rf main_tb
	rm -rf main_tb.ghw

