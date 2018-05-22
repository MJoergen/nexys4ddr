# Design Your Own Computer #

Welcome to this series where you will learn how to *Design Your Own Computer* on an FPGA!

## Overview of series ##

In the first few episodes we'll be focussing on the VGA output, essentially
building a (small) GPU. The reason is that this will give us excellent 
possibilities later on to view the internal state of the CPU.

Later we'll design and implement the 6502 processor. This is the same processor
that was used in e.g. the Commodore 64 computer from the 1980's. There is
an abundance of information on this processor on the Internet. In later episodes
I'll provide more links.

Of course, the ultimate goal is to have fun building stuff!

## Overall design ##

The computer we're building will be running on an FPGA board, and inside the FPGA there will be:
* VGA interface (GPU)
* Memory (RAM and ROM)
* 6502 CPU
* Keyboard interface

We will be designing and building these blocks roughly in the above order.

## List of episodes: ##
### VGA ###
1.  [**"Hello World"**](ep01_-_Hello_World). Here you will generate a
    checkerboard pattern on the VGA output.
2.  [**"Binary Digits"**](ep02_-_Binary_Digits). Here you will learn how to
    display a string of binary digits on VGA.
### Memory ###
3.  [**"Adding memory to the system"**](ep03_-_Memory). Here we will add memory
    to the system, and display accesses on VGA.
4.  [**"Adding hexadecimal output to VGA"**](ep04_-_Hexadecimal). Here we will
    implement a complete font and show data in hexadecimal format.
### CPU ###
5.  [**"Datapath"**](ep05_-_Datapath). Here the skeleton of the CPU datapath
    will be developed. Instructions implemented:  1/151.
6.  [**"Load and Store"**](ep06_-_Load_And_Store). We will add instructions
    that load and store in memory. Instructions implemented:  4/151.
7.  [**"Control logic"**](ep07_-_Control_Logic). The control logic will be
    greatly expanded. Instructions implemented:  4/151.
8.  [**"ALU"**](ep08_-_ALU). Here the Arithmetic and Logic Unit will be added
    to the CPU. Instructions implemented: 16/151.
9.  [**"Branching"**](ep09_-_Branching). We add conditional jumps to allow
    brancing.  Instructions implemented: 31/151.
10. [**"Assembler"**](ep10_-_Assembler). Now we use an assembler to compile
    programs with.  Instructions implemented: 31/151.
11. [**"Zero Page"**](ep11_-_Zero_Page). We build on the datapath to support
    the zero-page addressing mode.  Instructions implemented: 39/151.
12. [**"Stack Pointer"**](ep12_-_Stack_Pointer). We add the stack pointer and
    can now support subroutine calls.  Instructions implemented: 45/151.
13. [**"More ALU"**](ep13_-_More_ALU). We expand the ALU and add several more
    instructions.  Instructions implemented: 64/151.
14. [**"Registers X and Y"**](ep14_-_Registers_X_and_Y). We add the two
    remaining registers 'X' and 'Y'.  Instructions implemented: 90/151.
15. [**"Indexed addressing"**](ep15_-_Indexed_Addressing). We implement
    the indexed addressing modes. Instructions implemented: 132/151.
16. [**"Indirect addressing"**](ep15_-_Indirect_Addressing). We finish (almost)
    the CPU by adding support for indirect addressing modes. Instructions
    implemented: 150/151.
### VGA part 2 ###
17. [**"Text display"**](ep16_-_Text_Display). We expand on the VGA module
    by adding a screen memory to contain the text to be displayed.
18. [**"Sprites"**](ep17_-_Sprites). We add sprites (moveable objects) to the
    VGA module.
19. [**"Interrupts"**](ep18_-_Interrupts). We add interrupt support to the CPU.
### Keyboard ###
20. [**"Keyboard"**](ep19_-_Keyboard). We are now ready to add the keyboard
    interface.

More to come soon...

## Prerequisites ##

### FPGA board ###

To get started you need an FPGA board. There are many possibilities, e.g.
* [Nexys 4 DDR](https://reference.digilentinc.com/reference/programmable-logic/nexys-4-ddr/start)
(from Digilent). This is the one I am using (but somewhat of an overkill for this project).
* [Basys 3](https://reference.digilentinc.com/reference/programmable-logic/basys-3/start)
(from Digilent). Less expensive.
* [Go board](https://www.nandland.com/goboard/introduction.html)
(from Nandland). Even less expensive.

Make sure that the FPGA board you buy has (at least) the following features:
* VGA connector
* USB input connector (for keyboard)
* Crystal oscillator

### FPGA toolchain (software) ###

You need a tool chain for programming the FPGA. There are three major FPGA vendors:
* Xilinx
* Intel (formerly Altera)
* Lattice

The Nexys 4 DDR board uses a Xilinx FPGA, and the toolchain is called
[Vivado](https://www.xilinx.com/support/download.html).
Use the Webpack edition, because it is free to use.

## Recommended additional information ##

I recommend watching the video series 
[Building an 8-bit breadboard computer!](https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU)
by Ben Eater. He goes into great depth explaining the concepts and elements in
a computer. The design we're building will be somewhat more elaborate and have
more features. This is largely due to the many possibilities of using FPGAs.

I also recommend watching (at least the first half of) the video series
[Computation Structures](https://www.youtube.com/playlist?list=PLqAMlAbd8sIuiuk_yJeqCWWxe7jxWgswj)
from MIT. These are university lectures explaining very clearly the concepts involved in digital design.

I will in this series assume you are at least a little familiar with logic
gates and digital electronics.

I will also assume you are comfortable in at least one other programming
language, e.g. C, C++, Java, or similar.

## About me ##

I'm currently working as a professional FPGA developer, but have previously
been teaching the subjects mathematics, physics, and programming in High School.
Before that I've worked for twelve years as a software developer.

As a child I used to program in assembler on the Commodore 64. This "heritage"
is reflected in some of the design choices for the present project, e.g.
choosing the 6502 processor.

