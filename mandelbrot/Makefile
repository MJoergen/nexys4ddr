XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# Name of top level module
NAME = mandelbrot

# List of sources files
SRC  = src/add_overflow.vhd
SRC += src/iterator.vhd
SRC += src/column.vhd
SRC += src/priority.vhd
SRC += src/priority_pipeline.vhd
SRC += src/scheduler.vhd
SRC += src/dispatcher.vhd
SRC += src/disp_mem.vhd
SRC += src/disp.vhd
SRC += src/pix.vhd
SRC += src/clk.vhd
SRC += src/mandelbrot.vhd

# Files used during simulation
TBS = dispatcher column iterator mult priority_pipeline

# Testbench simulated by the "check" target
TB = dispatcher
TB_EXE = $(TB)_tb
TB_SRC = $(SRC) sim/$(TB)_tb.vhd
WAVE = sim/$(TB).ghw
SAVE = sim/$(TB).gtkw


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
	@echo "  check           Simulate a single testbench (TB=$(TB)) using ghdl and show waveform in gtkwave"
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

# Simulate a single testbench (TB=<name>) and show the waveform
.PHONY: check
check: run
	gtkwave $(WAVE) $(SAVE)

.PHONY: run
run: $(TB_SRC)
	ghdl -i --std=08 --work=work $(TB_SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules -P../xilinx-vivado $(TB_EXE)
	ghdl -r --std=08 $(TB_EXE) --assert-level=error --wave=$(WAVE) --stop-time=2100us

clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf $(NAME).bit
	rm -rf $(NAME).dcp
	rm -rf .Xil
	rm -rf .cache
	rm -rf work-obj08.cf
	rm -rf unisim-obj08.cf
	rm -rf $(TB_EXE)
	rm -rf */*.ghw
	rm -rf *.o
	rm -rf fsm_encoding.os

