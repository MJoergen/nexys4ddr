XILINX_DIR = /opt/Xilinx/Vivado/2017.3

# Name of top level module
NAME = mandelbrot

# List of sources files
SRC  = src/add_overflow.vhd
SRC += src/iterator.vhd
SRC += src/column.vhd
SRC += src/priority.vhd
SRC += src/priority_pipeline.vhd
SRC += src/dispatcher.vhd
SRC += src/disp.vhd
SRC += src/pix.vhd
SRC += src/clk.vhd
SRC += src/mandelbrot.vhd

# Files used during simulation
TB = dispatcher
#TB = column
#TB = iterator
#TB = mult
#TB = priority_pipeline
TB_EXE = $(TB)_tb
TB_SRC = $(SRC) sim/$(TB)_tb.vhd
WAVE = sim/$(TB).ghw
SAVE = sim/$(TB).gtkw


#####################################
# Generate bit-file and program FPGA
#####################################

$(NAME).bit: $(NAME).tcl $(SRC) $(NAME).xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

fpga: $(NAME).bit
	djtgcfg prog -d Nexys4DDR -i 0 --file $<


#####################################
# Simulation
#####################################

.PHONY: sim
sim: $(TB_SRC)
	ghdl -i --std=08 --work=work $(TB_SRC)
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules -P../xilinx-vivado $(TB_EXE)
	ghdl -r --std=08 $(TB_EXE) --assert-level=error --wave=$(WAVE) --stop-time=200us
	gtkwave $(WAVE) $(SAVE)

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

