TOP = vga

SRC  = src/clk_wiz_0_clk_wiz.vhd
SRC += src/clk_wiz_0.vhd
SRC += src/MouseCtl.vhd
SRC += src/MouseDisplay.vhd
SRC += src/Ps2Interface.vhd
SRC += src/vga_ctrl.vhd
XDC  = src/$(TOP).xdc

TCL = vivado.tcl
DCP = $(TOP).dcp

PART = xc7a100tcsg324-1

SYNTH: $(TCL)
	. /opt/Xilinx/Vivado/2017.2/settings64.sh; vivado -mode tcl -source $(TCL)
junk += vivado.jou
junk += vivado.log
junk += fsm_encoding.os
junk += $(DCP)

$(TCL) : $(SRC)
	echo "create_project -in_memory -part $(PART)" > $(TCL)
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

clean::
	rm -r -f $(junk)
