# Design Your Own Computer - Episode 1 : "Hello World"

Welcome to this first episode of "Design Your Own Computer", where we draw a
checker board pattern on the VGA output.

## Files generated in this series:
* vga.vhd   : Main source file
* vga.xdc   : Pin locations (specific for each FPGA board)
* vga.tcl   : List of commands for Vivado
* Makefile  : Overall project makefile

## Key learnings in this episode:
* Each signal may only be assigned values in one process. If more than one process
is assigned to a signal, then the error "Multiple Driver" will result. This is
because this essentially corresponds to a short-ciruit within the FPGA, and
fortunately the toolchain prevents that :-)

