SRC  = eth_rx.vhd eth_tx.vhd
SRC += tb_eth.vhd sim_tx.vhd sim_rx.vhd
TB   = tb_eth
WAVE = tb_eth.ghw
SAVE = tb_eth.gtkw


#####################################
# Simulation
#####################################

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=1us
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

