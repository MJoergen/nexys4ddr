XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SRCS  = top.vhd cdc.vhd clk_rst.vhd wide_fifo.vhd
SRCS += eth/fifo.vhd eth/strip_crc.vhd eth/byte2wide.vhd eth/wide2byte.vhd
SRCS += eth/eth_rx.vhd eth/eth_tx.vhd eth/eth.vhd
SRCS += eth/eth_types.vhd eth/arp.vhd eth/icmp.vhd eth/udp.vhd
SRCS += math/gcd.vhd math/mult.vhd math/math.vhd math/divmod.vhd math/amm.vhd math/cf.vhd math/add_mult.vhd math/sqrt.vhd
SRCS += vga/vga.vhd vga/pix.vhd vga/rom.vhd 

top.bit: top.tcl $(SRCS) top.xdc Makefile
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

top.tcl: Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(SRCS)  }" >> $@
	echo "read_xdc top.xdc" >> $@
	echo "set_property XPM_LIBRARIES {XPM_FIFO} [current_project]" >> $@
	echo "synth_design -top top -part xc7a100tcsg324-1 -flatten_hierarchy none" >> $@
	echo "place_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force top.dcp" >> $@
	echo "write_bitstream -force top.bit" >> $@
	echo "exit" >> $@

fpga: top.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<

#####################################
# Simulation
#####################################

TB     = tb
TB_SRC = $(TB).vhd
WAVE   = $(TB).ghw
SAVE   = $(TB).gtkw

sim: $(SRC)
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -i --std=08 --work=work $(SRCS) $(TB_SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=60us
	gtkwave $(WAVE) $(SAVE)


clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf top.tcl
	rm -rf top.bit
	rm -rf top.dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf unisim-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)

