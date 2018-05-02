# Design Your Own Computer, Episode 1 : "Hello World"

Welcome to this first episode of "Design Your Own Computer", where we draw a
checker board pattern on the VGA output.

## Overview of series

In the first few episode we'll be focussing on the VGA output, essentially
building a (small) GPU. The reason is that this will give us excellent 
possibilities later on to view the internal state of the CPU.

Later we'll design and implement the 6502 processor. This is the same processor
that was used in e.g. the Commodore 64 computer from the 1980's. There is
an abundance of information on this processor on the Internet. In later episodes
I'll provide more links.

Of course, the ultimate goal is to have fun building stuff!

## Overall design

The computer we're building will consist of the following parts:
* 6502 CPU
* Memory (RAM and ROM)
* VGA driver
* Keyboard interface

## Prerequisites

### FPGA board

To get started you need an FPGA board. There are many possibilities, e.g.
* [https://reference.digilentinc.com/reference/programmable-logic/nexys-4-ddr/start](Nexys 4 DDR) (from Digilent). This is the one I am using.
* [https://reference.digilentinc.com/reference/programmable-logic/basys-3/start](Basys 3) (from Digilent). Less expensive.
* [https://www.nandland.com/goboard/introduction.html](Go board) (from Nandland). Even less expensive.

Make sure that the FPGA board you buy has the following features:
* VGA connector
* USB input connector (for keyboard)
* Crystal oscillator

### FPGA toolchain (software)

You need a tool chain for the FPGA. There are three major FPGA vendor:
* Xilinx
* Intel (Altera)
* Lattice

The Nexys 4 DDR board uses a Xilinx FPGA, and the toolchain is called
[https://www.xilinx.com/support/download.html](Vivado)
Use the Webpack edition, because it is free to use.

## Files generated in this series:
* vga.vhd   : Main source file
* vga.xdc   : Pin locations (specific for each FPGA board)
* vga.tcl   : List of commands for Vivado
* Makefile  : Overall project makefile

## Learnings:
* Each signal may only be assigned values in one process. If more than one process
is assigned to a signal, then the error "Multiple Driver" will result. This is
because this essentially corresponds to a short-ciruit, and fortunately the toolchain
prevents that :-)

## Recommended additional information

I recommend watching the video series 
[https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU](Building
an 8-bit breadboard computer!) by Ben Eater. He goes into great depth
explaining the concepts and elements in a computer. The design we're building
will be somewhat more elaborate and have more features. This is largely due to
the possibilities of using FPGAs.

I also recommend watching (at least the first half of) the video series
[https://www.youtube.com/playlist?list=PLqAMlAbd8sIuiuk_yJeqCWWxe7jxWgswj](Computation Structures) from MIT. These are university lectures explaining very clearly the concepts involved in digital design.

I will in this series assume you are at least a little familiar with logic
gates and digital electronics.

I will also assume you are comfortable in at least one other programming
language, e.g. C, C++, Java, or similar.

## About me

I'm currently working as a professional FPGA developer, but have previously
been teaching the subhects mathematics, physics, and programming in High School.
Before that I've worked for twelve years as a software developer.

As a child I used to program in assembler on the Commodore 64. This "heritage"
is reflected in some of the design choices for the present project, e.g.
choosing the 6502 processor.

