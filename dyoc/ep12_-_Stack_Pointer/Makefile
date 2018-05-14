XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC = comp.vhd \
		vga/sync.vhd vga/font.vhd vga/digits.vhd vga/vga.vhd \
		mem/ram.vhd mem/rom.vhd mem/mem.vhd \
		cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd
XDC = comp.xdc
TB  = tb.vhd

comp.bit: $(SRC) $(XDC) mem/rom.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source comp.tcl"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file comp.bit

sim: $(SRC) $(TB) mem/rom.txt
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=tb.ghw --stop-time=10us
	gtkwave tb.ghw tb.gtkw

mem/rom.o: mem/rom.s
	ca65 $<
mem/rom.bin: mem/rom.o
	ld65 -C ld.cfg $<
mem/rom.txt: mem/rom.bin
	./bin2hex.py $< $@

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf .Xil
	rm -rf .cache
	rm -rf comp.dcp
	rm -rf *.o
	rm -rf work-obj93.cf
	rm -rf tb
	rm -rf tb.ghw
	rm -rf mem/rom.o
	rm -rf mem/rom.bin
	rm -rf mem/rom.txt
