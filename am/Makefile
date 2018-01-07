# Name of top level module
TOP = am

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd

# VGA driver
SRC += src/vga/vga_ctrl.vhd
SRC += src/vga/vga_char_rom.vhd
SRC += src/vga/vga_disp.vhd
SRC += src/vga/vga_sprite.vhd
SRC += src/vga/vga_module.vhd

# MC68000 CPU
SRC += src/cpu/cpu_module.vhd

stoptime = --stop-time=150us

include ../xilinx.mk

