OUTDIR ?= build
XDC    ?= src/$(TOP).xdc
TCL    ?= $(TOP).tcl
DCP    ?= $(TOP).dcp
PART   ?= xc7a100tcsg324-1 # For the Nexys4DDR board.
ENV    ?= /opt/Xilinx/Vivado/2017.2/settings64.sh

all: synth

# Generate tcl-file for vivado batch mode
$(TCL) : $(SRC) Makefile
	echo "set outputDir $(OUTDIR)" > $(TCL)
	echo "file mkdir \$$outputDir" >> $(TCL)
	echo "read_vhdl -library xil_defaultlib {" >> $(TCL)
	for file in $(SRC); do          \
			echo "  $$file" >> $(TCL); \
	done;
	echo "}" >> $(TCL)
	echo "read_xdc $(XDC)" >> $(TCL)
	echo "synth_design -top $(TOP) -part $(PART)" >> $(TCL)
	echo "write_checkpoint -force $(DCP)" >> $(TCL)
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

.PHONY: clean
clean::
	rm -r -f $(junk)
