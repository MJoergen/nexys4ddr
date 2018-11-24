XILINX_DIR = /opt/Xilinx/Vivado/2017.3

MAIN = main/main.vhd \
		 main/cpu/cpu.vhd main/cpu/datapath.vhd main/cpu/ctl.vhd main/cpu/pc.vhd main/cpu/ar.vhd main/cpu/hi.vhd main/cpu/lo.vhd main/cpu/alu.vhd main/cpu/sr.vhd main/cpu/sp.vhd main/cpu/xr.vhd main/cpu/yr.vhd main/cpu/zp.vhd \
		 main/mem/mem.vhd main/mem/rom.vhd main/mem/ram.vhd
SRC  = $(MAIN) \
		 comp.vhd waiter.vhd clk.vhd cdc.vhd \
		 vga/vga.vhd vga/digits.vhd vga/pix.vhd vga/font.vhd vga/opcodes.vhd
XDC  = comp.xdc
TB = main_tb
TB_SRC = main/$(TB).vhd
WAVE   = main/$(TB).ghw
SAVE   = main/$(TB).gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(XDC) main/mem/rom.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Compile target program
#####################################

main/mem/rom.o: main/mem/rom.s
	ca65 $<
main/mem/rom.bin: main/mem/rom.o
	ld65 -C ld.cfg $<
main/mem/rom.txt: main/mem/rom.bin
	./bin2hex.py $< $@


#####################################
# Simulation
#####################################

sim: $(MAIN) $(TB_SRC) main/mem/rom.txt
	ghdl -i --std=08 --work=work $(MAIN) $(TB_SRC)
	ghdl -m --std=08 -fexplicit $(TB)
	ghdl -r --std=08 $(TB) --assert-level=error --wave=$(WAVE) --stop-time=40us
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
	rm -rf work-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)
	rm -rf main/mem/rom.o
	rm -rf main/mem/rom.bin
	rm -rf main/mem/rom.txt
	rm -rf a.out

