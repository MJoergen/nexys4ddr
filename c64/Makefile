# Name of top level module
TOP = nexys4ddr

# Platform specific files
SRC    = src/nexys4ddr/nexys4ddr.vhd
SRC   += src/nexys4ddr/ethernet/mac.vhd
SRC   += src/nexys4ddr/ethernet/smi.vhd
SRC   += src/nexys4ddr/ethernet/reset.vhd
SRC   += src/nexys4ddr/ethernet/ethernet.vhd
SRC   += src/nexys4ddr/clk_wiz_0.vhd
SRC   += src/nexys4ddr/clk_wiz_0_clk_wiz.vhd
SRC   += src/nexys4ddr/debounce.vhd
SRC   += src/nexys4ddr/clk_rst.vhd
TB_SRC = src/nexys4ddr/$(testbench).vhd
XDC    = src/nexys4ddr/$(TOP).xdc

# Top level module
SRC += src/hack.vhd

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

# Keyboard
SRC += src/keyboard/ps2.vhd
SRC += src/keyboard/bytefifo.vhd
SRC += src/keyboard/keyboard.vhd

# Machine code
PROG_SRC    = src/prog/demo.c
PROG_SRC   += src/prog/keyboard.c
PROG_SRC   += src/prog/circle.c
PROG_SRC   += src/prog/smult.c
#PROG_SRC    = src/prog/text.c
#PROG_SRC    = src/prog/circle.c
#PROG_SRC    = src/prog/cputest.c
#PROG_SRC    = src/prog/scroll.c
LD_CFG      = src/prog/ld.cfg
VECTORS_AS  = src/prog/vectors.s

stoptime = --stop-time=150us

include ../xilinx.mk

