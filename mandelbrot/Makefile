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

# Testbenches, i.e. sim/<name>_tb.vhd
TBS = dispatcher column iterator scheduler view vga disp_mem priority_pipeline

# Testbench simulated by the "run" and "check" targets. Must be specified on
# the command line, e.g. "make run TB=iterator".
TB =

# Maximum simulation time. This must be longer than the slowest testbench. Most
# testbenches stop by themselves, the slowest of those is view (about 2.7 ms).
# The testbench priority_pipeline does not stop by itself. It needs 655 us to
# test all 65536 input vectors.
STOP_TIME = 3ms

TB_EXE = $(TB)_tb
# The clock module and the top level use Xilinx primitives, and are not
# simulated. The bit-accurate model of the iterator (iterator_model_pkg.vhd) is
# used by several testbenches.
TB_SRC = $(filter-out src/clk.vhd src/mandelbrot.vhd,$(SRC)) sim/iterator_model_pkg.vhd sim/$(TB)_tb.vhd
WAVE = sim/$(TB).ghw
SAVE = sim/$(TB).gtkw

GHDL_OPTS = --std=08 --ieee=synopsys -frelaxed-rules


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
run: $(TB_SRC)
	ghdl -i $(GHDL_OPTS) --work=work $(TB_SRC)
	ghdl -m $(GHDL_OPTS) $(TB_EXE)
	ghdl -r $(GHDL_OPTS) $(TB_EXE) --assert-level=error --wave=$(WAVE) --stop-time=$(STOP_TIME)

endif

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
	rm -rf $(addsuffix _tb,$(TBS))
	rm -rf */*.ghw
	rm -rf *.o
	rm -rf fsm_encoding.os
	rm -rf sim/main_out.txt

