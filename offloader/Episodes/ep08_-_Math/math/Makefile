## This makefile is used to simulate each of the modules.
## Type 'make help'

# List of source files
SRC  = math.vhd sqrt.vhd

# List of test benches
TBS  = tb_sqrt
TBS += tb_math

# Select last testbench as default
TB  ?= $(lastword $(TBS))

SRC += $(TB).vhd
WAVE = $(TB).ghw
SAVE = $(TB).gtkw


#####################################
# Simulation
#####################################

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules $(TB)
	ghdl -r $(TB) --assert-level=error --wave=$(WAVE) --stop-time=20us

show: $(WAVE) $(SAVE)
	gtkwave $(WAVE) $(SAVE)

list:
	@echo "The following test benches are available:"
	@echo $(TBS)

all:
	for i in $(TBS); do make TB=$$i || { echo "Stopped due to error"; exit 1; } ; done

help:
	@echo "This makefile is used to simulate each of the modules."
	@echo "Usage:"
	@echo "'make'         simulates the default module."
	@echo "'make show'    invokes the GUI to display the waveform."
	@echo "'make list'    shows a list of the available test benches."
	@echo "'make TB=<tb>' simulates a single test bench."
	@echo "'make all'     simulates all test benches."
	@echo "'make clean'   removes all object files."
	@echo "'make help'    displays this message."


#####################################
# Cleanup
#####################################

clean:
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf unisim-obj08.cf
	rm -rf $(TBS)
	rm -rf *.ghw

