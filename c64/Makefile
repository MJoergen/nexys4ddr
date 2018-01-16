# Name of top level module
TOP = hack

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd
SRC += src/clk_rst.vhd

# VGA driver
SRC += src/vga/bitmaps.vhd
#SRC += src/vga/rom_file.vhd
SRC += src/vga/vga_ctrl.vhd
SRC += src/vga/vga_disp.vhd
SRC += src/vga/vga_sprite.vhd
SRC += src/vga/vga_module.vhd

# CPU
SRC += src/cpu/regs.vhd
SRC += src/cpu/ctl.vhd
SRC += src/cpu/alu.vhd
SRC += src/cpu/pc.vhd
SRC += src/cpu/cpu_module.vhd

# Memory
SRC += src/mem_file.vhd

# Control logic
SRC += src/cs.vhd

stoptime = --stop-time=5000ns

include ../xilinx.mk

PROG_SRC = circle.c

# Don't change below here
VECTORS_AS = vectors.s
LD_CFG = ld.cfg
PROG_AS  = $(PROG_SRC:.c=.s)
ALL_AS = $(VECTORS_AS) $(PROG_AS)
ALL_OBJ = $(ALL_AS:.s=.o)

rom.bin:	$(ALL_OBJ)
	ld65 -C $(LD_CFG) $(ALL_OBJ)

%.o: %.s
	ca65 $<

%.s: %.c
	cc65 $<

