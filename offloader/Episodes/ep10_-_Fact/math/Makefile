XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SRC  = math.vhd sqrt.vhd cf.vhd divmod.vhd amm.vhd add_mult.vhd
SRC += alg.vhd gcd.vhd divexact.vhd fact.vhd divexact.vhd math.vhd factors.vhd jacobi.vhd
TB   = tb_math
#TB   = tb_alg
#TB   = tb_jacobi
#TB   = tb_cf
#TB   = tb_amm
#TB   = tb_add_mult
#TB   = tb_divmod
#TB   = tb_sqrt

SRC += $(TB).vhd
WAVE = $(TB).ghw
SAVE = $(TB).gtkw


#####################################
# Simulation
#####################################

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=10us
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

