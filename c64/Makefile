# Name of top level module
TOP = hack

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd

# VGA driver
SRC += src/vga/vga_ctrl.vhd
SRC += src/vga/vga_char_rom.vhd
SRC += src/vga/vga_disp.vhd
SRC += src/vga/vga_module.vhd

stoptime = --stop-time=50us

include ../xilinx.mk


