XILINX_DIR = /opt/Xilinx/Vivado/2017.3

SRC  = rmii_rx.vhd rmii_tx.vhd lan8720a.vhd
TB   = lan8720a_tb.vhd sim_tx.vhd sim_rx.vhd
WAVE = lan8720a_tb.ghw
SAVE = lan8720a_tb.gtkw


#####################################
# Simulation
#####################################

sim: $(SRC) 
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VCOMP.vhd
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/unisim_VPKG.vhd
	ghdl -i --std=08 --work=unisim $(XILINX_DIR)/data/vhdl/src/unisims/primitive/*.vhd
	ghdl -i --std=08 --work=work $(SRC) $(TB)
	ghdl -m --std=08 -frelaxed-rules lan8720a_tb
	ghdl -r lan8720a_tb --assert-level=error --wave=$(WAVE) --stop-time=1us
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
	rm -rf work-obj08.cf
	rm -rf unisim-obj08.cf
	rm -rf lan8720a_tb
	rm -rf lan8720a_tb.ghw

