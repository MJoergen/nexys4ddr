XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = comp.vhd ic.vhd\
		 vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
		 mem/memio.vhd mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
		 keyboard/ps2.vhd \
		 cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd
XDC  = comp.xdc
TB   = tb.vhd keyboard/ps2_tb.vhd
WAVE = tb.ghw
SAVE = tb.gtkw

# Include directory
C_INC = prog


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

lib/vectors.o: lib/vectors.s     # Hardware interrupt vectors
	ca65 $< -o $@

lib/irq.o: lib/irq.s             # IRQ and NMI vectors
	ca65 $< -o $@

lib/crt0.o: lib/crt0.s           # Reset vector
	ca65 $< -o $@

lib/vga_isr.o: lib/vga_isr.s     # VGA interrupt service routine
	ca65 $< -o $@

lib/kbd_isr.o: lib/kbd_isr.s     # KBD interrupt service routine
	ca65 $< -o $@

lib/printf.s: lib/printf.c
	cc65 -I $(C_INC) -g -t none -O $< -o $@

lib/printf.o: lib/printf.s
	ca65 $< -o $@

lib/keyboard.s: lib/keyboard.c
	cc65 -I $(C_INC) -g -t none -O $< -o $@

lib/keyboard.o: lib/keyboard.s
	ca65 $< -o $@

lib/vga.o: lib/vga.s
	ca65 $< -o $@

lib/comp.lib: lib/crt0.o lib/printf.o lib/kbd_isr.o lib/vga_isr.o lib/vga.o lib/irq.o lib/keyboard.o 
	cp lib/none.lib $@
	ar65 r $@ $^

#####################################
# Compile target program
#####################################

prog/main.s: prog/main.c
	cc65 -g -t none -O $< -o $@

prog/main.o: prog/main.s
	ca65 $< -o $@

prog/rom.bin: prog/main.o lib/vectors.o lib/comp.lib
	ld65 -m prog/rom.map -C ld.cfg $^

mem/rom.txt: prog/rom.bin
	./bin2hex.py $< $@


#####################################
# Simulation
#####################################

sim: $(SRC) $(TB) mem/rom.txt
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=$(WAVE) --stop-time=400us
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
	rm -rf lib/comp.lib
	rm -rf lib/*.o
	rm -rf lib/printf.s
	rm -rf lib/keyboard.s
	rm -rf prog/main.s
	rm -rf prog/*.o
	rm -rf prog/*.bin
	rm -rf prog/rom.map

