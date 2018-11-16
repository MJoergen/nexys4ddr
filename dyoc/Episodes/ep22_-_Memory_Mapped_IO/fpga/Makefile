XILINX_DIR = /opt/Xilinx/Vivado/2017.3

MAIN = main.vhd \
       cpu/cpu.vhd cpu/datapath.vhd cpu/ctl.vhd cpu/pc.vhd cpu/ar.vhd cpu/hi.vhd cpu/lo.vhd cpu/alu.vhd cpu/sr.vhd cpu/sp.vhd cpu/xr.vhd cpu/yr.vhd cpu/zp.vhd \
       mem/mem.vhd mem/rom.vhd mem/ram.vhd mem/dmem.vhd mem/memio.vhd
SRC  = $(MAIN) \
       comp.vhd waiter.vhd clk.vhd \
       vga/vga.vhd vga/overlay.vhd vga/pix.vhd vga/font.vhd vga/chars.vhd
XDC  = comp.xdc
TB   = main_tb.vhd
WAVE = main_tb.ghw
SAVE = main_tb.gtkw


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

sim: $(MAIN) $(TB) ../rom.txt
	ghdl -i --std=08 --work=work $(MAIN) $(TB)
	ghdl -m --std=08 --ieee=synopsys -fexplicit main_tb
	ghdl -r --std=08 main_tb --assert-level=error --wave=$(WAVE) --stop-time=400us
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
	rm -rf timing_summary.rpt
	rm -rf .cache
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf main_tb
	rm -rf main_tb.ghw
	rm -rf a.out

