XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SRC  = eth_rx.vhd fifo.vhd strip_crc.vhd byte2wide.vhd arp.vhd icmp.vhd wide2byte.vhd eth_tx.vhd eth.vhd wide_fifo.vhd
SRC += tb_eth.vhd
TB   = tb_eth
WAVE = tb_eth.ghw
SAVE = tb_eth.gtkw


#####################################
# Simulation
#####################################

sim: $(SRC)
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=3us
	gtkwave $(WAVE) $(SAVE)


#####################################
# Cleanup
#####################################

clean:
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf unisim-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)

