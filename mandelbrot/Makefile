XILINX_DIR = /opt/Xilinx/Vivado/2017.3

# Name of top level module
NAME = mandelbrot

# List of sources files
SRC  = src/mandelbrot.vhd

# Files used during simulation
TB = mandelbrot_tb
TB_SRC = $(SRC) sim/mandelbrot_tb.vhd
WAVE = sim/mandelbrot.ghw
SAVE = sim/mandelbrot.gtkw


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
	ghdl -m --std=08 --ieee=synopsys -frelaxed-rules -P../dyoc/Episodes/xilinx-vivado $(TB)
	ghdl -r --std=08 $(TB) --assert-level=error --wave=$(WAVE) --stop-time=20us
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
	rm -rf $(TB)
	rm -rf $(WAVE)
	rm -rf *.o
	rm -rf fsm_encoding.os

