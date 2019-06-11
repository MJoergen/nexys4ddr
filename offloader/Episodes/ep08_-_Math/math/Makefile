XILINX_DIR = /opt/Xilinx/Vivado/2018.2

SRC  = math.vhd sqrt.vhd
TB   = tb_math
TB   = tb_sqrt

SRC += $(TB).vhd
WAVE = $(TB).ghw
SAVE = $(TB).gtkw


#####################################
# Simulation
#####################################

sim: $(SRC)
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

