XILINX_DIR = /opt/Xilinx/Vivado/2021.2

GENERIC = -generic G_SIZE=72

SRCS  = top.vhd cdc.vhd clk_rst.vhd wide_fifo.vhd
SRCS += eth/fifo.vhd eth/strip_crc.vhd eth/byte2wide.vhd eth/wide2byte.vhd
SRCS += eth/eth_rx.vhd eth/eth_tx.vhd eth/eth.vhd
SRCS += eth/eth_types.vhd eth/arp.vhd eth/icmp.vhd eth/udp.vhd
SRCS += vga/vga.vhd vga/pix.vhd vga/rom.vhd 

MATH_SRCS = math/math.vhd math/sqrt.vhd

all: top.bit

synth_math.dcp: synth_math.tcl $(MATH_SRCS) top.xdc Makefile
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

synth_math.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "# Synthesize math module" >> $@
	echo "read_vhdl -vhdl2008 { $(MATH_SRCS)  }" >> $@
	echo "synth_design -top math -part xc7a100tcsg324-1 $(GENERIC) -flatten_hierarchy none -mode out_of_context" >> $@
	echo "write_checkpoint -force synth_math.dcp" >> $@
	echo "exit" >> $@


synth_top.dcp: synth_top.tcl $(SRCS) top.xdc Makefile
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

synth_top.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "# Synthesize top (static) part" >> $@
	echo "read_vhdl -vhdl2008 { $(SRCS)  }" >> $@
	echo "read_xdc top.xdc" >> $@
	echo "set_property XPM_LIBRARIES {XPM_FIFO} [current_project]" >> $@
	echo "synth_design -top top -part xc7a100tcsg324-1 $(GENERIC) -flatten_hierarchy none" >> $@
	echo "write_checkpoint -force synth_top.dcp" >> $@
	echo "exit" >> $@


top.bit: top.tcl $(SRCS) top.xdc Makefile synth_math.dcp synth_top.dcp
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

top.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "add_files synth_top.dcp" >> $@
	echo "add_files synth_math.dcp" >> $@
	echo "set_property SCOPED_TO_CELLS {i_math} [get_files synth_math.dcp]" >> $@
	echo "link_design -top top -part xc7a100tcsg324-1 -reconfig_partitions {i_math}" >> $@
	echo "# Create pblocks" >> $@
	#echo "create_pblock pblock_eth" >> $@
	#echo "add_cells_to_pblock [get_pblocks pblock_eth] [get_cells i_eth]" >> $@
	#echo "resize_pblock [get_pblocks pblock_eth] -add {CLOCKREGION_X0Y2:CLOCKREGION_X0Y3}" >> $@
	#echo "create_pblock pblock_vga" >> $@
	#echo "add_cells_to_pblock [get_pblocks pblock_vga] [get_cells i_vga]" >> $@
	#echo "resize_pblock [get_pblocks pblock_vga] -add {CLOCKREGION_X1Y2:CLOCKREGION_X1Y3}" >> $@
	echo "create_pblock pblock_math" >> $@
	echo "add_cells_to_pblock [get_pblocks pblock_math] [get_cells i_math]" >> $@
	echo "resize_pblock [get_pblocks pblock_math] -add {SLICE_X0Y0:SLICE_X89Y99 DSP48_X0Y0:DSP48_X2Y39 RAMB18_X0Y0:RAMB18_X3Y39 RAMB36_X0Y0:RAMB36_X3Y19}" >> $@
	echo "#################" >> $@
	echo "# Place and Route" >> $@
	echo "opt_design" >> $@
	echo "place_design" >> $@
	echo "phys_opt_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force top.dcp" >> $@
	echo "write_bitstream -force top.bit" >> $@
	echo "exit" >> $@

fpga: top.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf synth_math.tcl
	rm -rf synth_math.bit
	rm -rf synth_math.dcp
	rm -rf synth_top.tcl
	rm -rf synth_top.bit
	rm -rf synth_top.dcp
	rm -rf top.tcl
	rm -rf top.bit
	rm -rf top.dcp
	rm -rf .Xil
	rm -rf .cache

