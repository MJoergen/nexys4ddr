# This Makefile is built based on the documentation at 
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx2013_4/ug894-vivado-tcl-scripting.pdf
#
# In order to use it, you must set the following variables:
# TOP : Name of top level instance
# SRC : List of HDL source files.

# Synthesis
OUTDIR ?= build
XDC    ?= src/$(TOP).xdc
TCL    ?= $(TOP).tcl
PART   ?= xc7a100tcsg324-1 # For the Nexys4DDR board.
ENV    ?= /opt/Xilinx/Vivado/2017.2/settings64.sh

# Simulation
testbench  ?= $(TOP)_tb
TB_SRC     ?= src/$(testbench).vhd
wave       ?= $(TOP).ghw
wavesave   ?= src/$(testbench).gtkw
unisim_lib ?= unisim-obj93.cf
stoptime   ?= --stop-time=10us

UNISIMS_DIR = /opt/Xilinx/Vivado/2017.2/data/vhdl/src/unisims

all: synth

# Generate tcl-file for vivado batch mode
$(TCL) : $(SRC) Makefile
	cat ../reportCriticalPaths.tcl > $(TCL)
	# Step 1
	echo "# Step 1" >> $(TCL)
	echo "set outputDir $(OUTDIR)" >> $(TCL)
	echo "file mkdir \$$outputDir" >> $(TCL)
	# Step 2
	echo "# Step 2" >> $(TCL)
	echo "read_vhdl -library xil_defaultlib {" >> $(TCL)
	for file in $(SRC); do          \
			echo "  $$file" >> $(TCL); \
	done;
	echo "}" >> $(TCL)
	echo "read_xdc $(XDC)" >> $(TCL)
	# Step 3
	echo "# Step 3" >> $(TCL)
	echo "synth_design -top $(TOP) -part $(PART)" >> $(TCL)
	echo "write_checkpoint -force \$$outputDir/post_synth.dcp" >> $(TCL)
	echo "report_timing_summary -file \$$outputDir/post_synth_timing_summary.rpt" >> $(TCL)
	echo "report_utilization -file \$$outputDir/post_synth_util.rpt" >> $(TCL)
	echo "reportCriticalPaths \$$outputDir/post_synth_critpath_report.csv" >> $(TCL)
	# Step 4
	echo "# Step 4" >> $(TCL)
	echo "opt_design" >> $(TCL)
	echo "reportCriticalPaths \$$outputDir/post_opt_critpath_report.csv" >> $(TCL)
	echo "place_design" >> $(TCL)
	echo "report_clock_utilization -file \$$outputDir/clock_util.rpt" >> $(TCL)
	echo "phys_opt_design" >> $(TCL)
	echo "write_checkpoint -force \$$outputDir/post_place.dcp" >> $(TCL)
	echo "report_utilization -file \$$outputDir/post_place_util.rpt" >> $(TCL)
	echo "report_timing_summary -file \$$outputDir/post_place_timing_summary.rpt" >> $(TCL)
	# Step 5
	echo "# Step 5" >> $(TCL)
	echo "route_design" >> $(TCL)
	echo "write_checkpoint -force \$$outputDir/post_route.dcp" >> $(TCL)
	echo "report_route_status -file \$$outputDir/post_route_status.rpt" >> $(TCL)
	echo "report_timing_summary -file \$$outputDir/post_route_timing_summary.rpt" >> $(TCL)
	echo "report_power -file \$$outputDir/post_route_power.rpt" >> $(TCL)
	echo "report_drc -file \$$outputDir/post_imp_drc.rpt" >> $(TCL)
	echo "write_vhdl -force \$$outputDir/impl_netlist.vhdl" >> $(TCL)
	# Step 6
	echo "# Step 6" >> $(TCL)
	echo "write_bitstream -force \$$outputDir/$(TOP).bit" >> $(TCL)
	echo "exit" >> $(TCL)
junk += $(TCL)

.PHONY: synth
synth: $(TCL)
	. $(ENV); vivado -mode tcl -source $(TCL)
junk += vivado.jou
junk += vivado.log
junk += fsm_encoding.os
junk += .Xil
junk += build
junk += $(DCP)
junk += usage_statistics_webtalk.xml
junk += usage_statistics_webtalk.html

.PHONY: sim
sim: $(wave)
	gtkwave $(wave) $(wavesave)

$(wave): $(testbench)
	-ghdl -r $(testbench) --assert-level=error --wave=$(wave) $(stoptime)
junk += $(wave)

$(testbench): $(testbench).o $(unisim_lib) $(vfiles) $(tb_sources)
	ghdl -m --ieee=synopsys -fexplicit $(testbench)
junk += $(testbench)

$(testbench).o: $(SRC) $(TB_SRC)
	ghdl -i --work=work $(SRC) $(TB_SRC)
junk += *.o work-obj93.cf 

$(unisim_lib):
	ghdl -i --work=unisim $(UNISIMS_DIR)/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(UNISIMS_DIR)/unisim_VPKG.vhd
	ghdl -i --work=unisim $(UNISIMS_DIR)/primitive/*vhd
junk += unisim-obj93.cf 


.PHONY: clean
clean::
	rm -r -f $(junk)

