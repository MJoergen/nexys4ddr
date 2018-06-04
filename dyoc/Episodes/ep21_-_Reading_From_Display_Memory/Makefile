XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = comp.vhd \
		 vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
		 mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
		 cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd
XDC  = comp.xdc
TB   = tb.vhd
WAVE = tb.ghw
SAVE = tb.gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC) mem/rom.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Compile runtime library
#####################################

prog/crt0.o: prog/crt0.s
	ca65 $< -o $@

prog/comp.lib: prog/crt0.o
	cp prog/cc65.lib $@
	ar65 a $@ $^

prog/vectors.o: prog/vectors.s
	ca65 $< -o $@


#####################################
# Compile target program
#####################################

prog/printf.s: prog/printf.c
	cc65 -g -t none -O $< -o $@
prog/rom.s: prog/rom.c
	cc65 -g -t none -O $< -o $@

prog/printf.o: prog/printf.s
	ca65 $< -o $@
prog/rom.o: prog/rom.s
	ca65 $< -o $@
prog/irq.o: prog/irq.s
	ca65 $< -o $@
prog/rom.bin: prog/printf.o prog/rom.o prog/vectors.o prog/irq.o prog/comp.lib
	ld65 -m prog/rom.map -C ld.cfg $^
mem/rom.txt: prog/rom.bin
	./bin2hex.py $< $@


#####################################
# Simulation
#####################################

sim: $(SRC) $(TB) mem/rom.txt
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=$(WAVE) --stop-time=5us
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
	rm -rf mem/rom.txt
	rm -rf a.out
	rm -rf prog/rom.s
	rm -rf prog/printf.s
	rm -rf prog/*.o
	rm -rf prog/*.bin
	rm -rf prog/comp.lib
	rm -rf prog/rom.map

