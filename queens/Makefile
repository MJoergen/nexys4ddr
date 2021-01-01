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

# Synthesis using yosys

work-obj93.cf: $(SOURCES)
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -a -fsynopsys $^

synth: work-obj93.cf
	yosys -m ghdl -p 'ghdl -fsynopsys queens_top; synth_xilinx -top queens_top -edif queens_top.edif' > yosys.log

