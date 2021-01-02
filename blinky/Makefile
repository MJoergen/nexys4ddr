PRJNAME  = blinky
TOPLEVEL = top
SOURCES  = blinky.vhd
XDC      = nexys.xdc

# Don't change anything below this line
NEXTPNR  = /home/mike/git/daveshah1/nextpnr-xilinx
CHIPDB   = $(NEXTPNR)/xilinx/xc7a100t.bin
ARCH     = xc7
FAMILY   = artix7
PART     = xc7a100tcsg324-1

$(PRJNAME).bit: $(PRJNAME).fasm
	${XRAY_DIR}/utils/fasm2frames.py --part $(PART) --db-root ${XRAY_DIR}/database/$(FAMILY) $^ > $(PRJNAME).frames
	${XRAY_DIR}/build/tools/xc7frames2bit --part_file ${XRAY_DIR}/database/$(FAMILY)/$(PART)/part.yaml --part_name $(PART) --frm_file $(PRJNAME).frames --output_file $@

$(PRJNAME).fasm: $(PRJNAME).json
	$(NEXTPNR)/nextpnr-xilinx --chipdb $(CHIPDB) --xdc $(XDC) --json $^ --write $(PRJNAME)_routed.json --fasm $@

$(PRJNAME).json: work-obj93.cf
	yosys -m ghdl -p "ghdl -fsynopsys $(TOPLEVEL); synth_xilinx -flatten -abc9 -nobram -arch $(ARCH) -top $(TOPLEVEL); write_json $@"

work-obj93.cf: $(SOURCES)
	ghdl -a -fsynopsys $^

clean:
	rm -f work-obj93.cf
	rm -f $(PRJNAME).json
	rm -f $(PRJNAME)_routed.json
	rm -f $(PRJNAME).frames
	rm -f $(PRJNAME).bit
	rm -f $(PRJNAME).fasm

