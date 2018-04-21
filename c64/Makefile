# Name of top level module
TOP = nexys4ddr

# Platform specific files
SRC    = src/nexys4ddr/nexys4ddr.vhd
SRC   += src/nexys4ddr/clk_rst.vhd
SRC   += src/nexys4ddr/ethernet/eth_tx.vhd
SRC   += src/nexys4ddr/ethernet/eth_rx.vhd
SRC   += src/nexys4ddr/ethernet/eth_smi.vhd
SRC   += src/nexys4ddr/ethernet/eth.vhd
SRC   += src/nexys4ddr/ethernet/read_smi.vhd
SRC   += src/nexys4ddr/ethernet/encap.vhd
SRC   += src/nexys4ddr/ethernet/decap.vhd
SRC   += src/nexys4ddr/ethernet/strip_crc.vhd
SRC   += src/nexys4ddr/ethernet/receive.vhd
SRC   += src/nexys4ddr/ethernet/compress.vhd
SRC   += src/nexys4ddr/ethernet/convert.vhd
SRC   += src/nexys4ddr/ethernet/stat.vhd
SRC   += src/nexys4ddr/ethernet/ethernet.vhd
SRC   += src/nexys4ddr/fifo_alt.vhd
SRC   += src/nexys4ddr/fifo_width_change.vhd
SRC   += src/nexys4ddr/clk_wiz_0.vhd
SRC   += src/nexys4ddr/clk_wiz_0_clk_wiz.vhd
SRC   += src/nexys4ddr/debounce.vhd
XDC    = src/nexys4ddr/$(TOP).xdc

# Top level module
SRC += src/addr_mux.vhd
SRC += src/hack.vhd

# Test bench
TB_SRC  = src/nexys4ddr/$(testbench).vhd
TB_SRC += src/keyboard/ps2_tb.vhd

# VGA driver
SRC += src/vga/sync.vhd
SRC += src/vga/chars.vhd
SRC += src/vga/sprites.vhd
SRC += src/vga/vga_module.vhd

# CPU
SRC += src/cpu/regs.vhd
SRC += src/cpu/ctl.vhd
SRC += src/cpu/alu.vhd
SRC += src/cpu/pc.vhd
SRC += src/cpu/sr.vhd
SRC += src/cpu/sp.vhd
SRC += src/cpu/addr.vhd
SRC += src/cpu/addr2.vhd
SRC += src/cpu/cpu_module.vhd

# Memory
SRC += src/mem/mem_file.vhd
SRC += src/mem/mem.vhd
SRC += src/mem/dmem_file.vhd
SRC += src/mem/dmem.vhd
SRC += src/mem/conf_mem.vhd
SRC += src/mem/bitmaps_mem.vhd
SRC += src/mem/addr_decode.vhd
SRC += src/mem/mem_module.vhd

# Clock domain crossing
SRC += src/cdc/cdcpulse.vhd
SRC += src/cdc/cdc.vhd
SRC += src/cdc/cdcvector.vhd

# Keyboard
SRC += src/keyboard/ps2.vhd
SRC += src/keyboard/bytefifo.vhd
SRC += src/keyboard/keyboard.vhd

# Machine code
PROG_SRC    = src/prog/demo.c
PROG_SRC   += src/prog/keyboard.c
#PROG_SRC   = src/prog/circle_test.c
PROG_SRC   += src/prog/circle.c
PROG_SRC   += src/prog/smult.c
PROG_SRC   += src/prog/umult.c
#PROG_SRC   = src/prog/keyboard_test.c
#PROG_SRC    = src/prog/text.c
#PROG_SRC    = src/prog/circle.c
#PROG_SRC    = src/prog/cputest.c
#PROG_SRC    = src/prog/memtest.c
#PROG_SRC    = src/prog/scroll.c

#PROG_SRC    = src/prog/ttt.c
#PROG_SRC   += src/prog/ttt_vga.c
#PROG_SRC   += src/prog/ttt_ai.c
#PROG_SRC   += src/prog/keyboard.c

PROG_SRC    = src/prog/tennis.c
PROG_SRC   += src/prog/tennis_ball.c
PROG_SRC   += src/prog/tennis_player.c
PROG_SRC   += src/prog/keyboard.c
PROG_SRC   += src/prog/smult.c

LD_CFG      = src/prog/ld.cfg
VECTORS_AS  = src/prog/vectors.s

stoptime = --stop-time=150us

# The following is used for the compress.vhd unit test.
#SRC    = src/nexys4ddr/compress.vhd
#SRC   += src/nexys4ddr/fifo_width_change.vhd
#SRC   += src/nexys4ddr/ethernet/fifo_alt.vhd
#TB_SRC = src/nexys4ddr/compress_tb.vhd
#TOP = compress

include ../xilinx.mk

