XILINX_DIR = /opt/Xilinx/Vivado/2017.3

MAIN = main.vhd \
		 vga/vga.vhd vga/digits.vhd vga/font.vhd \
		 cpu/cpu.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/alu.vhd \
		 mem/mem.vhd
SRC  = comp.vhd clk.vhd waiter.vhd $(MAIN)
XDC  = comp.xdc
TB   = main_tb.vhd
WAVE = main_tb.ghw
SAVE = main_tb.gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC) mem/mem.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Compile target program
#####################################

mem/mem.o: mem/mem.s
	ca65 $<
mem/mem.bin: mem/mem.o
	ld65 -C ld.cfg $<
mem/mem.txt: mem/mem.bin
	./bin2hex.py $< $@


#####################################
# Simulation
#####################################

sim: $(MAIN) $(TB) mem/mem.txt
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
	rm -rf .cache
	rm -rf *.o
	rm -rf work-obj93.cf
	rm -rf main_tb
	rm -rf main_tb.ghw
	rm -rf mem/mem.o
	rm -rf mem/mem.bin
	rm -rf mem/mem.txt

