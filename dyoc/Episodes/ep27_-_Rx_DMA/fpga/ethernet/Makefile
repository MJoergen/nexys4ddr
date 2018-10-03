XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = ethernet.vhd rx_dma.vhd fifo.vhd rx_header.vhd \
       lan8720a/lan8720a.vhd lan8720a/rmii_rx.vhd lan8720a/rmii_tx.vhd
TB = ethernet_tb.vhd lan8720a_sim.vhd sim_tx.vhd
WAVE = ethernet_tb.ghw
SAVE = ethernet_tb.gtkw


#####################################
# Simulation
#####################################

sim: $(SRC) 
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -i --work=work $(SRC) $(TB)
	ghdl -m --ieee=synopsys -fexplicit ethernet_tb
	ghdl -r ethernet_tb --assert-level=error --wave=$(WAVE) --stop-time=100us
	gtkwave $(WAVE) $(SAVE)


#####################################
# Cleanup
#####################################

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf *.o
	rm -rf comp.dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf work-obj93.cf
	rm -rf unisim-obj93.cf
	rm -rf ethernet_tb
	rm -rf ethernet_tb.ghw

