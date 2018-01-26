# Name of top level module
TOP = hack

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/debounce.vhd
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd
SRC += src/clock/clk_wiz_cpu.vhd
SRC += src/clock/clk_wiz_cpu_clk_wiz.vhd
SRC += src/clock/clk_rst.vhd

# VGA driver
SRC += src/vga/bitmaps_mem.vhd
SRC += src/vga/conf_stat.vhd
SRC += src/vga/sync.vhd
SRC += src/vga/chars.vhd
SRC += src/vga/sprites.vhd
SRC += src/vga/vga_module.vhd

# CPU
SRC += src/cpu/regs.vhd
SRC += src/cpu/ctl.vhd
SRC += src/cpu/alu.vhd
SRC += src/cpu/pc.vhd
SRC += src/cpu/cpu_module.vhd

# Memory
SRC += src/mem/rom_file.vhd
SRC += src/mem/mem.vhd
SRC += src/mem/cs.vhd

# Clock domain crossing
SRC += src/cdc/cdcpulse.vhd
SRC += src/cdc/cdcvector.vhd

# Machine code
PROG_SRC    = src/prog/circle.c
#PROG_SRC    = src/prog/cputest.c
LD_CFG      = src/prog/ld.cfg
VECTORS_AS  = src/prog/vectors.s

stoptime = --stop-time=200us

include ../xilinx.mk

