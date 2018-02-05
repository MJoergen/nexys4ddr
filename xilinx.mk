###############################################################################
#
# This Makefile is built based on the documentation at 
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx2013_4/ug894-vivado-tcl-scripting.pdf
#
###############################################################################
#
# Usage:
#
# In order to use it, you must include this file from a separate Makefile with
# the following contents:
#
#     # Name of top level module
#     TOP = toplevel
#
#     # List of sources files
#     SRC  = src/$(TOP).vhd
#     SRC += src/clk.vhd
#     SRC += ### etc.
#
#     include ../xilinx.mk
#
#
# Assumptions made by this Makefile system:
# * The testbench is located in src/$(TOP)_tb.vhd. Can be overridden by the variable TB_SRC.
# * The constraint file is located in src/$(TOP).xdc. Can be overridden by the variable XDC.
#
# 
# Supported make targets are:
# * sim     : Run simulation (default target).
# * bit     : Create a bit-file.
# * program : Program the FPGA board with the bit-file.
# * clean   : Delete all compiled files.
#
###############################################################################
#
# DON'T CHANGE ANYTHING BELOW THIS LINE !!!!!
#
###############################################################################

# Variables used for synthesis
VIVADO ?= /opt/Xilinx/Vivado/2017.3
OUTDIR ?= build
XDC    ?= src/$(TOP).xdc
TCL    ?= $(TOP).tcl
PART   ?= xc7a100tcsg324-1 # For the Nexys4DDR board.
ENV    ?= $(VIVADO)/settings64.sh

# Variables used for simulation
testbench  ?= $(TOP)_tb
TB_SRC     ?= src/$(testbench).vhd
wave       ?= $(TOP).ghw
wavesave   ?= src/$(testbench).gtkw
unisim_lib ?= unisim-obj93.cf
stoptime   ?= --stop-time=10us

UNISIMS_DIR = $(VIVADO)/data/vhdl/src/unisims

# Default target is simulation.
all: sim

###############################################################################

.PHONY: sim
sim: $(wave)
	gtkwave $(wave) $(wavesave)

$(wave): $(testbench) rom.txt ram.txt
	-ghdl -r $(testbench) --assert-level=error --wave=$(wave) $(stoptime)
junk += $(wave)

.PHONY: elaborate
elaborate: $(testbench)

$(testbench): $(unisim_lib) $(SRC) $(TB_SRC) Makefile
	ghdl -i --work=work $(SRC) $(TB_SRC)
	ghdl -m --ieee=synopsys -fexplicit $(testbench)
junk += $(testbench)
junk += *.o work-obj93.cf 

$(unisim_lib):
	ghdl -i --work=unisim $(UNISIMS_DIR)/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(UNISIMS_DIR)/unisim_VPKG.vhd
	ghdl -i --work=unisim $(UNISIMS_DIR)/primitive/*vhd
junk += unisim-obj93.cf 

###############################################################################

# Generate tcl-file for vivado batch mode
$(TCL) : $(SRC) Makefile rom.txt ram.txt
	cat ../reportCriticalPaths.tcl > $(TCL)
	echo "set_param messaging.defaultLimit 1000" >> $(TCL)
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
	echo "synth_design -verbose -top $(TOP) -part $(PART) -flatten_hierarchy none -keep_equivalent_registers -resource_sharing off" >> $(TCL)
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

.PHONY: bit
bit: $(OUTDIR)/$(TOP).bit

$(OUTDIR)/$(TOP).bit: $(TCL)
	bash -c "source $(ENV); vivado -mode tcl -source $(TCL)"
junk += vivado*.jou
junk += vivado*.log
junk += fsm_encoding.os
junk += .Xil
junk += build
junk += $(DCP)
junk += usage_statistics_webtalk.xml
junk += usage_statistics_webtalk.html


.PHONY: program
program: $(OUTDIR)/$(TOP).bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $(OUTDIR)/$(TOP).bit

###############################################################################

include Makefile.prog

###############################################################################

.PHONY: clean
clean::
	rm -r -f $(junk)

