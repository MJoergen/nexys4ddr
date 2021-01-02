XILINX_DIR = /opt/Xilinx/Vivado/2019.2

PRJNAME  = queens
TOPLEVEL = queens_top
XDC      = src/queens_top.xdc
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

sim: work-obj93.cf
	ghdl -m queens_tb
	ghdl -r queens_tb --wave=queens_tb.ghw --stop-time=2us
	gtkwave queens_tb.ghw queens_tb.gtkw

sim_top: work-obj93.cf
	ghdl -m -fexplicit -fsynopsys queens_top_tb
	ghdl -r -fexplicit -fsynopsys queens_top_tb --wave=queens_top_tb.ghw --stop-time=2us
	gtkwave queens_top_tb.ghw queens_top_tb.gtkw


# Don't change anything below this line
NEXTPNR  = /home/mike/git/daveshah1/nextpnr-xilinx
CHIPDB   = $(NEXTPNR)/xilinx/xc7a100t.bin
ARCH     = xc7
FAMILY   = artix7
PART     = xc7a100tcsg324-1

synth: $(PRJNAME).bit

$(PRJNAME).bit: $(PRJNAME).fasm
	${XRAY_DIR}/utils/fasm2frames.py --part $(PART) --db-root ${XRAY_DIR}/database/$(FAMILY) $^ > $(PRJNAME).frames
	${XRAY_DIR}/build/tools/xc7frames2bit --part_file ${XRAY_DIR}/database/$(FAMILY)/$(PART)/part.yaml --part_name $(PART) --frm_file $(PRJNAME).frames --output_file $@

$(PRJNAME).fasm: $(PRJNAME).json
	$(NEXTPNR)/nextpnr-xilinx --chipdb $(CHIPDB) --xdc $(XDC) --json $^ --write $(PRJNAME)_routed.json --fasm $@

$(PRJNAME).json: work-obj93.cf
	yosys -m ghdl -p "ghdl -fsynopsys $(TOPLEVEL); synth_xilinx -flatten -abc9 -nobram -arch $(ARCH) -top $(TOPLEVEL); write_json $@"

work-obj93.cf: $(SOURCES) $(TB_SOURCES)
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -a -fsynopsys $^

clean:
	rm -f work-obj93.cf
	rm -f unisim-obj93.cf
	rm -f $(PRJNAME).json
	rm -f $(PRJNAME)_routed.json
	rm -f $(PRJNAME).frames
	rm -f $(PRJNAME).bit
	rm -f $(PRJNAME).fasm
	rm -rf vivado/vivado.cache/
	rm -rf vivado/vivado.hw/
	rm -rf vivado/vivado.ip_user_files/
	rm -rf vivado/vivado.runs/
	rm -rf vivado/vivado.sim/

