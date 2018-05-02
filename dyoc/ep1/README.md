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

## VGA colour
The colour to the monitor is in the form of three analogue signals, one for each of Red, Green,
and Blue. Since the FPGA can only generate digital signals, a simple Digital-to-Analog converter
is built into the board, in the form of a resistor network. In that way, the Nexys 4 DDR board
supports four bits of information for each of the three colour channels, i.e. 12 colour bits.
However, since this is going to be an 8-bit computer, we will only use three bits for red and green,
and two bits for blue.

## VGA timing
In this project we will work with a resolution of 640x480 pixels @ 60 Hz refresh rate, and 8-bit colours.
The VGA monitor draws each line, starting from the top, and in each line draws one pixel at a time, from
left to right.
However, due to historical reasons, the timing actually corresponds to a larger area of in total 800x525 pixels,
indicated as the black regions in the diagram below
![VGA timing](VGA_timing.png "VGA timing")
The two narrow bands in the diagram shows the timing of the two synchronization signals, *hs* and *vs*.
All the timing signals for this screen resolution is described on
[page 17](http://caxapa.ru/thumbs/361638/DMTv1r11.pdf) in the VESA monitor timing standard.

## Implementation (vga.vhd)
In the VHDL code we will have two pixel counters, x and y, where y is positive down. They will count from 0 to 799
and 0 to 524 respectively.

## Constraints (vga.xdc)
The toolchain needs to know which pins on the FPGA to use, and for this we must refer to the
[page 7](https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf)
on the hardware schematic diagram of the particular board used.

