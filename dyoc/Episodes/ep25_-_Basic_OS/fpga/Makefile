XILINX_ISE_DIR = /opt/Xilinx/14.7/ISE_DS

SRC  = comp.vhd ic.vhd\
		 vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
		 mem/memio.vhd mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
		 keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
		 cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd
XDC  = comp.xdc
TB   = tb.vhd keyboard/ps2_tb.vhd
WAVE = tb.ghw
SAVE = tb.gtkw

BIT = ../../ep24_-_Keyboard/fpga/comp.bit
BMM = ../../ep24_-_Keyboard/fpga/comp.bmm
ROM = ../rom.txt
MEM = comp.mem


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: $(BIT) $(BMM) $(MEM)
	bash -c "source $(XILINX_ISE_DIR)/settings64.sh ; data2mem -bm $(BMM) -bt $(BIT) -bd $(MEM) -o b comp.bit"

$(MEM): $(ROM)
	echo "@C000" > $(MEM)
	cat $(ROM) >> $(MEM)

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

sim: $(SRC) $(TB) $(ROM)
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=$(WAVE) --stop-time=250us
	gtkwave $(WAVE) $(SAVE)


#####################################
# Cleanup
#####################################

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf comp.bit
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf work-obj93.cf
	rm -rf tb
	rm -rf tb.ghw
	rm -rf $(MEM)
