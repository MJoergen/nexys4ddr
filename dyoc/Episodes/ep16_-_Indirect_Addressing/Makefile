XILINX_DIR = /opt/Xilinx/Vivado/2017.3

MAIN = main.vhd \
		 vga/vga.vhd vga/digits.vhd vga/font.vhd \
		 cpu/cpu.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/alu.vhd \
		 mem/mem.vhd mem/rom.vhd mem/ram.vhd
SRC  = comp.vhd clk.vhd waiter.vhd $(MAIN)
XDC  = comp.xdc
TB   = main_tb.vhd
WAVE = main_tb.ghw
SAVE = main_tb.gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC) mem/rom.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Compile target program
#####################################

mem/rom.o: mem/rom.s
	ca65 $<
mem/rom.bin: mem/rom.o
	ld65 -C ld.cfg $<
mem/rom.txt: mem/rom.bin
	./bin2hex.py $< $@


#####################################
# Simulation
#####################################

sim: $(MAIN) $(TB) mem/rom.txt
	ghdl -i --work=work $(MAIN) $(TB)
	ghdl -m --ieee=synopsys -fexplicit main_tb
	ghdl -r main_tb --assert-level=error --wave=$(WAVE) --stop-time=40us
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
	rm -rf mem/rom.o
	rm -rf mem/rom.bin
	rm -rf mem/rom.txt

