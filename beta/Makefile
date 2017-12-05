# Name of top level module
TOP = beta

# List of sources files
SRC  = src/$(TOP).vhd

# Clocks
SRC += src/clock/clk_wiz_vga.vhd
SRC += src/clock/clk_wiz_vga_clk_wiz.vhd
SRC += src/clock/clk_wiz_cpu.vhd
SRC += src/clock/clk_wiz_cpu_clk_wiz.vhd

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

# Memory
SRC += src/cpu/imem.vhd
SRC += src/cpu/dmem.vhd

stoptime = --stop-time=5us

include ../xilinx.mk


