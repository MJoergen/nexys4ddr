XILINX_DIR = /opt/Xilinx/Vivado/2019.2

SOURCES += src/counter.vhd
SOURCES += src/clk_wiz_0.vhd
SOURCES += src/clk_wiz_0_clk_wiz.vhd
SOURCES += src/vga_bitmap_pkg.vhd
SOURCES += src/vga_ctrl.vhd
SOURCES += src/vga_disp_queens.vhd
SOURCES += src/vga.vhd
SOURCES += src/display_seg.vhd
SOURCES += src/display_digit.vhd
SOURCES += src/display_int2seg.vhd
SOURCES += src/display.vhd
SOURCES += src/queens.vhd
SOURCES += src/queens_top.vhd

TB_SOURCES += src/queens_tb.vhd
TB_SOURCES += src/queens_top_tb.vhd

queens.bit: queens.tcl $(SOURCES)
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: queens.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf queens.bit
	rm -rf queens.dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf queens_top.edif
	rm -rf unisim-obj93.cf
	rm -rf work-obj93.cf
	rm -rf yosys.log
	rm -rf *.ghw

# Simulation using ghdl

sim: work-obj93.cf
	ghdl -m queens_tb
	ghdl -r queens_tb --wave=queens_tb.ghw --stop-time=2us
	gtkwave queens_tb.ghw queens_tb.gtkw

sim_top: work-obj93.cf
	ghdl -m -fexplicit -fsynopsys queens_top_tb
	ghdl -r -fexplicit -fsynopsys queens_top_tb --wave=queens_top_tb.ghw --stop-time=2us
	gtkwave queens_top_tb.ghw queens_top_tb.gtkw


# Synthesis using yosys

work-obj93.cf: $(SOURCES) $(TB_SOURCES)
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -a -fsynopsys $^

synth: work-obj93.cf
	yosys -m ghdl -p 'ghdl -fsynopsys queens_top; synth_xilinx -top queens_top -edif queens_top.edif' > yosys.log

