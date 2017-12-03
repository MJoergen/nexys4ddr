# Name of top level module
TOP = beta

# List of sources files
SRC  = src/$(TOP).vhd

# VGA driver
SRC += src/vga/vga_module.vhd
SRC += src/vga/clk_wiz_0.vhd
SRC += src/vga/clk_wiz_0_clk_wiz.vhd
SRC += src/vga/vga_ctrl.vhd
SRC += src/vga/vga_bitmap_pkg.vhd
SRC += src/vga/vga_disp.vhd

# CPU module
SRC += src/cpu/cpu_module.vhd
SRC += src/cpu/alu/alu_module.vhd
SRC += src/cpu/alu/add.vhd
SRC += src/cpu/alu/cmp.vhd
SRC += src/cpu/alu/boole.vhd
SRC += src/cpu/alu/shift.vhd
SRC += src/cpu/alu/mult.vhd

stoptime = --stop-time=5us

include ../xilinx.mk


