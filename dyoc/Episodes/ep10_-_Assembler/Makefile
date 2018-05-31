XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC = comp.vhd \
		vga/vga.vhd vga/digits.vhd vga/font.vhd \
		mem/mem.vhd \
		cpu/cpu.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/alu.vhd
XDC = comp.xdc
TB  = tb.vhd


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

sim: $(SRC) $(TB) mem/mem.txt
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=tb.ghw --stop-time=40us
	gtkwave tb.ghw tb.gtkw


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
	rm -rf mem/mem.o
	rm -rf mem/mem.bin
	rm -rf mem/mem.txt
