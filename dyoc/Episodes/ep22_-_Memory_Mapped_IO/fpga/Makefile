XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
		 mem/memio.vhd mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
		 cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd cpu/cycle.vhd \
		 comp.vhd
XDC  = comp.xdc
TB   = tb.vhd
WAVE = tb.ghw
SAVE = tb.gtkw


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

sim: $(SRC) $(TB) ../rom.txt
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit tb
	ghdl -r tb --assert-level=error --wave=$(WAVE) --stop-time=200us
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
