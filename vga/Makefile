SRC  = src/clk_wiz_0_clk_wiz.vhd
SRC += src/clk_wiz_0.vhd
SRC += src/MouseCtl.vhd
SRC += src/MouseDisplay.vhd
SRC += src/Ps2Interface.vhd
SRC += src/vga_ctrl.vhd

SYNTH: $(SRC)
	source /opt/Xilinx/Vivado/2017.2/settings64.sh
	echo "create_project -in_memory -part xc7a100tcsg324-1" > vivado.tcl
	echo "read_vhdl -library xil_defaultlib {" >> vivado.tcl
	for file in $(SRC); do          \
			echo "  $$file" >> vivado.tcl; \
	done;
	echo "}" >> vivado.tcl
	echo "synth_design -top vga_ctrl -part xc7a100tcsg324-1" >> vivado.tcl
	echo "exit" >> vivado.tcl
	vivado -mode tcl -source vivado.tcl
