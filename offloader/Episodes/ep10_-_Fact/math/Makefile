XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SRC  = mult.vhd gcd.vhd math.vhd amm.vhd divmod.vhd cf.vhd add_mult.vhd
SRC += fact.vhd divexact.vhd alg.vhd
SRC += tb_math.vhd
TB   = tb_math
WAVE = tb_math.ghw
SAVE = tb_math.gtkw


#####################################
# Simulation
#####################################

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=2us
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

