# Name of top level module
TOP = beta

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd
SRC += src/clock/clk_wiz_cpu.vhd
SRC += src/clock/clk_wiz_cpu_clk_wiz.vhd
SRC += src/clock/clken.vhd

# VGA driver
SRC += src/vga/vga_module.vhd
SRC += src/vga/vga_ctrl.vhd
SRC += src/vga/vga_bitmap_pkg.vhd
SRC += src/vga/vga_disp.vhd

# CPU module
SRC += src/cpu/pc.vhd
SRC += src/cpu/regfile.vhd
SRC += src/cpu/ctl.vhd
SRC += src/cpu/alu/add.vhd
SRC += src/cpu/alu/cmp.vhd
SRC += src/cpu/alu/boole.vhd
SRC += src/cpu/alu/shift.vhd
SRC += src/cpu/alu/mult.vhd
SRC += src/cpu/alu/alu_module.vhd
SRC += src/cpu/cpu_module.vhd

# Separate testbench for the CPU module
CPU_TB_SRC   = src/cpu/cpu_module_tb.vhd
CPU_TB       = cpu_module_tb
CPU_WAVE     = src/cpu_module.ghw
CPU_WAVESAVE = src/cpu_module_tb.gtkw

# Memory
SRC += src/mem/mem.vhd

stoptime = --stop-time=5us

# Separate target to simulate the CPU
.PHONY: cpu
cpu: $(unisim_lib) $(SRC) $(CPU_TB_SRC)
	ghdl -i --work=work $(SRC) $(CPU_TB_SRC)
	ghdl -m --ieee=synopsys -fexplicit $(CPU_TB)
	ghdl -r $(CPU_TB) --assert-level=error --wave=$(CPU_WAVE) $(stoptime)
	gtkwave $(CPU_WAVE) $(CPU_WAVESAVE)

include ../xilinx.mk


