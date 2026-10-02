XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# Name of top level module
NAME = mandelbrot

# List of sources files
SRC  = src/iterator.vhd
SRC += src/column.vhd
SRC += src/priority.vhd
SRC += src/priority_pipeline.vhd
SRC += src/scheduler.vhd
SRC += src/dispatcher.vhd
SRC += src/disp_mem.vhd
SRC += src/disp.vhd
SRC += src/pix.vhd
SRC += src/vga.vhd
SRC += src/view.vhd
SRC += src/main.vhd
SRC += src/clk.vhd
SRC += src/mandelbrot.vhd

# Files used during simulation
TBS = dispatcher column iterator scheduler view vga mult_macro priority_pipeline

# Testbench simulated by the "run" and "check" targets. Must be specified on
# the command line, e.g. "make run TB=iterator".
TB =

# Maximum simulation time. This must be longer than the slowest testbench. Most
# testbenches stop by themselves, the slowest of those is view (about 2.7 ms).
# The testbench priority_pipeline does not stop by itself. It needs 655 us to
# test all 65536 input vectors.
STOP_TIME = 3ms

TB_EXE = $(TB)_tb
# The clock module and the top level use Xilinx primitives, and are not simulated
TB_SRC = $(filter-out src/clk.vhd src/mandelbrot.vhd,$(SRC)) sim/$(TB)_tb.vhd
WAVE = sim/$(TB).ghw
SAVE = sim/$(TB).gtkw

# The simulation library "unimacro" is built into this directory. It only
# contains the model of mult_macro in sim/mult_macro.vhd.
LIB_DIR     = sim/lib
UNIMACRO_CF = $(LIB_DIR)/unimacro/unimacro-obj08.cf
GHDL_OPTS   = --std=08 --ieee=synopsys -frelaxed-rules -P$(LIB_DIR)/unimacro


#####################################
# Help (default target)
#####################################

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  help            Show this help text (default)"
	@echo "  vivado          Synthesize and implement the design using Vivado ($(NAME).bit)"
	@echo "  fpga            Program the Nexys4DDR board with $(NAME).bit"
	@echo "  sim             Simulate all testbenches using ghdl"
	@echo "  run             Simulate a single testbench (TB=<name>) using ghdl, without gtkwave"
	@echo "  check           Simulate a single testbench (TB=<name>) using ghdl and show waveform in gtkwave"
	@echo "  clean           Remove generated files"
	@echo ""
	@echo "Testbench is selected by TB=<name>, e.g. 'make check TB=iterator'."
	@echo "Available testbenches: $(TBS)"


#####################################
# Generate bit-file and program FPGA
#####################################

.PHONY: vivado
vivado: $(NAME).bit

$(NAME).bit: $(NAME).tcl $(SRC) $(NAME).xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

.PHONY: fpga
fpga: $(NAME).bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

# Simulate all testbenches (without opening the waveform viewer)
.PHONY: sim
sim:
	@for tb in $(TBS); do \
	   echo "=== Simulating $$tb ==="; \
	   $(MAKE) --no-print-directory run TB=$$tb || exit 1; \
	done

ifeq ($(TB),)

# No testbench specified, so list the possible ones
.PHONY: run check
run check:
	@echo "Please specify a testbench using TB=<name>, e.g. 'make $@ TB=iterator'."
	@echo "Available testbenches:"
	@for tb in $(TBS); do echo "  $$tb"; done

else

# Simulate a single testbench (TB=<name>) and show the waveform
.PHONY: check
check: run
	gtkwave $(WAVE) $(SAVE)

.PHONY: run
run: $(TB_SRC) $(UNIMACRO_CF)
	ghdl -i $(GHDL_OPTS) --work=work $(TB_SRC)
	ghdl -m $(GHDL_OPTS) $(TB_EXE)
	ghdl -r $(GHDL_OPTS) $(TB_EXE) --assert-level=error --wave=$(WAVE) --stop-time=$(STOP_TIME)

endif

# Build the simulation library
$(UNIMACRO_CF): sim/mult_macro.vhd
	mkdir -p $(LIB_DIR)/unimacro
	ghdl -a --std=08 --ieee=synopsys -frelaxed-rules --work=unimacro --workdir=$(LIB_DIR)/unimacro $<

.PHONY: clean
clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf clockInfo.txt
	rm -rf tight_setup_hold_pins.txt
	rm -rf $(NAME).bit
	rm -rf $(NAME).dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf work-obj08.cf
	rm -rf $(TB_EXE)
	rm -rf */*.ghw
	rm -rf $(LIB_DIR)
	rm -rf *.o
	rm -rf fsm_encoding.os
	rm -rf sim/main_out.txt

