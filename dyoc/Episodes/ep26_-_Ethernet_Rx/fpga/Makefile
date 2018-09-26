XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = chipset/ic.vhd chipset/waiter.vhd chipset/timer.vhd \
		 vga/overlay.vhd vga/chars.vhd vga/font.vhd vga/vga.vhd \
		 mem/memio.vhd mem/dmem.vhd mem/ram.vhd mem/rom.vhd mem/mem.vhd \
		 keyboard/ps2.vhd keyboard/scancode.vhd keyboard/keyboard.vhd \
		 cpu/zp.vhd cpu/sr.vhd cpu/regfile.vhd cpu/hilo.vhd cpu/pc.vhd cpu/cycle.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/cpu.vhd cpu/alu.vhd \
		 ethernet/ethernet.vhd ethernet/rx_dma.vhd ethernet/fifo.vhd ethernet/strip_crc.vhd \
		 comp.vhd
XDC  = comp.xdc
SYNTH = ethernet/lan8720a/lan8720a.vhd ethernet/lan8720a/rmii_rx.vhd
TB   = tb.vhd keyboard/ps2_tb.vhd ethernet/lan8720a/lan8720a_sim.vhd
WAVE = tb.ghw
SAVE = tb.gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

comp.bit: comp.tcl $(SRC) $(SYNTH) $(XDC) ../rom.txt
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: comp.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

sim: $(TB) $(SRC) ../rom.txt
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
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
	rm -rf *.o
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf work-obj93.cf
	rm -rf unisim-obj93.cf
	rm -rf tb
	rm -rf tb.ghw
