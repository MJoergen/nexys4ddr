# Name of top level module
TOP = hack

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd

# VGA driver
SRC += src/vga/bitmaps.vhd
SRC += src/vga/rom_file.vhd
SRC += src/vga/vga_ctrl.vhd
SRC += src/vga/vga_disp.vhd
SRC += src/vga/vga_sprite.vhd
SRC += src/vga/vga_module.vhd

# Configuration
SRC += src/config.vhd

stoptime = --stop-time=250us

include ../xilinx.mk


