XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = chipset/ic.vhd chipset/waiter.vhd chipset/timer.vhd \
		 vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
		 main/mem/dmem.vhd main/mem/ram.vhd main/mem/rom.vhd main/mem/mem.vhd main/mem/memio.vhd \
		 keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
		 main/cpu/zp.vhd main/cpu/sr.vhd main/cpu/regfile.vhd main/cpu/hilo.vhd main/cpu/pc.vhd main/cpu/datapath.vhd main/cpu/ctl.vhd main/cpu/cpu.vhd main/cpu/alu.vhd \
		 comp.vhd
XDC  = comp.xdc
TB = tb
TB_SRC = main/$(TB).vhd keyboard/ps2_tb.vhd
WAVE   = main/$(TB).ghw
SAVE   = main/$(TB).gtkw


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

sim: $(SRC) $(TB_SRC) ../rom.txt
	ghdl -i --std=08 --work=work $(SRC) $(TB_SRC)
	ghdl -m --std=08 -fexplicit $(TB)
	ghdl -r --std=08 $(TB) --assert-level=error --wave=$(WAVE) --stop-time=200us
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
	rm -rf .cache
	rm -rf work-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)
	rm -rf comp.bit
	rm -rf comp.bmm
	rm -rf fsm_encoding.os

