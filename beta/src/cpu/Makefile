# Name of top level module
TOP = cpu_module

# List of sources files
SRC  = $(TOP).vhd
SRC += pc.vhd
SRC += regfile.vhd
SRC += alu/alu_module.vhd
SRC += alu/add.vhd
SRC += alu/cmp.vhd
SRC += alu/boole.vhd
SRC += alu/shift.vhd
SRC += alu/mult.vhd
TB_SRC = cpu_module_tb.vhd
wavesave = cpu_module_tb.gtkw

stoptime = --stop-time=5us

include ../../../xilinx.mk


