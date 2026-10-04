XILINX_DIR = /opt/Xilinx/2025.1/Vivado

# Name of the design. Used for the Vivado script.
NAME = mandelbrot

# Target boards. Each board has its own FPGA part, top level module and
# constraint file (<board>.xdc). The make target <board> generates the
# bit-file <board>.bit.
BOARDS = nexys4ddr mega65-r6

nexys4ddr_PART = xc7a100tcsg324-1
nexys4ddr_TOP  = nexys4ddr
nexys4ddr_SRC  = src/nexys4ddr.vhd

mega65-r6_PART = xc7a200tfbg484-2
mega65-r6_TOP  = mega65_r6
mega65-r6_SRC  = src/mega65_r6.vhd

# List of source files common to all boards. This is the only list: it is
# also given to the Vivado script (mandelbrot.tcl), followed by the top level
# module of the board.
SRC  = src/main/iterator.vhd
SRC += src/main/job.vhd
SRC += src/main/job_scheduler.vhd
SRC += src/main/res_scheduler.vhd
SRC += src/main/dispatcher.vhd
SRC += src/disp_mem.vhd
SRC += src/vga/video_pkg.vhd
SRC += src/vga/palette_pkg.vhd
SRC += src/vga/disp.vhd
SRC += src/vga/font_pkg.vhd
SRC += src/vga/overlay.vhd
SRC += src/vga/pix.vhd
SRC += src/vga/vga.vhd
SRC += src/main/view.vhd
SRC += src/main/fps.vhd
SRC += src/main/seg.vhd
SRC += src/main/main.vhd
SRC += src/clk_rst.vhd

# Testbenches, i.e. sim/<name>_tb.vhd. The slowest are listed first, so that
# they are started first by "make sim".
TBS = vga overlay dispatcher disp_mem iterator view job job_scheduler res_scheduler fps

# Testbench simulated by the "run" and "check" targets. Must be specified on
# the command line, e.g. "make run TB=iterator".
TB =

# Generics of the testbench, as a list of <name>=<value>, e.g.
# GENERICS="G_PIXELS=4". Only used by main_tb.
GENERICS =

# Maximum simulation time. This must be longer than the slowest testbench. The
# testbenches stop by themselves, the slowest of those is vga (about 5.3 ms,
# for 1280x1024).
STOP_TIME = 6ms

TB_EXE = $(TB)_tb
# The clock module uses Xilinx primitives, and is not simulated. The top
# levels (<board>_SRC) are not simulated either. The bit-accurate model of the
# iterator (iterator_model_pkg.vhd) is used by several testbenches.
TB_SRC = $(filter-out src/clk_rst.vhd,$(SRC)) sim/iterator_model_pkg.vhd sim/$(TB)_tb.vhd
WAVE = sim/$(TB).ghw
SAVE = sim/$(TB).gtkw

# Each testbench has its own GHDL work directory, so that several testbenches
# can be analyzed and simulated at the same time (see "make sim").
WORKDIR = build/$(TB)

GHDL_OPTS = --std=08 -frelaxed-rules --workdir=$(WORKDIR)


#####################################
# Help (default target)
#####################################

.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  help            Show this help text (default)"
	@echo "  nexys4ddr       Synthesize and implement the design for the Nexys 4 DDR using Vivado (nexys4ddr.bit)"
	@echo "  mega65-r6       Synthesize and implement the design for the MEGA65 R6 using Vivado (mega65-r6.bit)"
	@echo "  fpga            Program the Nexys 4 DDR board with nexys4ddr.bit"
	@echo "  sim             Simulate all testbenches in parallel using ghdl (logs in build/)"
	@echo "  run             Simulate a single testbench (TB=<name>) using ghdl, without gtkwave"
	@echo "  check           Simulate a single testbench (TB=<name>) using ghdl and show waveform in gtkwave"
	@echo "  clean           Remove generated files"
	@echo ""
	@echo "Testbench is selected by TB=<name>, e.g. 'make check TB=iterator'."
	@echo "Available testbenches: $(TBS)"


#####################################
# Generate bit-file and program FPGA
#####################################

.PHONY: $(BOARDS)
$(BOARDS): %: %.bit

# The arguments of the Vivado script are the board name, the FPGA part, the
# top level module, and the source files.
.SECONDEXPANSION:
%.bit: $(NAME).tcl %.xdc $(SRC) $$($$*_SRC)
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $< -tclargs $* $($*_PART) $($*_TOP) $(SRC) $($*_SRC)"

.PHONY: fpga
fpga: nexys4ddr.bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

# Simulate all testbenches (without opening the waveform viewer). The
# testbenches are run in parallel, each by its own target sim-<name>, using
# SIM_JOBS jobs (default: the number of CPUs). If make itself is run with -j,
# that is used instead. The output of each testbench goes to
# build/<name>.log, and a summary is shown at the end. The exit status is
# non-zero if any testbench fails.
SIM_JOBS ?= $(shell nproc 2>/dev/null || echo 1)
SIM_TARGETS = $(addprefix sim-,$(TBS))

.PHONY: sim
sim:
	@rm -f $(addprefix build/,$(addsuffix .status,$(TBS)))
	@$(MAKE) --no-print-directory -k $(if $(findstring jobserver,$(MAKEFLAGS)),,-j$(SIM_JOBS)) $(SIM_TARGETS) || true
	@echo ""
	@echo "=== Summary ==="
	@fail=0; \
	for tb in $(TBS); do \
	   status=`cat build/$$tb.status 2>/dev/null || echo "FAIL (not run)"`; \
	   printf "  %-15s %s\n" $$tb "$$status"; \
	   case "$$status" in PASS*) ;; *) fail=1 ;; esac; \
	done; \
	if [ $$fail -ne 0 ]; then echo "Some testbenches FAILED"; exit 1; fi; \
	echo "All testbenches passed"

# Simulate a single testbench as part of "make sim", with the output going to
# build/<name>.log.
.PHONY: $(SIM_TARGETS)
$(SIM_TARGETS): sim-%:
	@mkdir -p build
	@echo "=== Simulating $* ==="
	@start=`date +%s`; \
	if $(MAKE) --no-print-directory run TB=$* > build/$*.log 2>&1; then \
	   result="PASS"; \
	else \
	   result="FAIL"; \
	fi; \
	secs=$$((`date +%s` - start)); \
	echo "$$result ($${secs}s)" > build/$*.status; \
	echo "=== $*: $$result ($${secs}s), log in build/$*.log ==="; \
	[ $$result = PASS ]

ifeq ($(TB),)

# No testbench specified, so list the possible ones
.PHONY: run check
run check:
	@echo "Please specify a testbench using TB=<name>, e.g. 'make $@ TB=iterator'."
	@echo "Available testbenches:"
	@for tb in $(TBS); do echo "  $$tb"; done

else

# Simulate a single testbench (TB=<name>) and show the waveform. Not all
# testbenches have a GTKWave save file (sim/<name>.gtkw).
.PHONY: check
check: run
	gtkwave $(WAVE) $(wildcard $(SAVE))

.PHONY: run
run: $(TB_SRC)
	@mkdir -p $(WORKDIR)
	ghdl -i $(GHDL_OPTS) --work=work $(TB_SRC)
	ghdl -m $(GHDL_OPTS) $(TB_EXE)
	ghdl -r $(GHDL_OPTS) $(TB_EXE) --assert-level=error --wave=$(WAVE) --stop-time=$(STOP_TIME) $(addprefix -g,$(GENERICS))

endif

.PHONY: clean
clean:
	rm -rf usage_statistics_webtalk.*
	rm -rf vivado*
	rm -rf clockInfo.txt
	rm -rf tight_setup_hold_pins.txt
	rm -rf $(addsuffix .bit,$(BOARDS))
	rm -rf $(addsuffix .dcp,$(BOARDS))
	rm -rf .Xil
	rm -rf .cache
	rm -rf work-obj08.cf
	rm -rf build
	rm -rf $(addsuffix _tb,$(TBS))
	rm -rf */*.ghw
	rm -rf *.o
	rm -rf fsm_encoding.os
	rm -rf sim/main_out.txt

