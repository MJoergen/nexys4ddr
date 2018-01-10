# C-64 inspired computer

This is a computer inspired by the legendary Commodore 64.
The computer consists of the following parts:
* 6502 CPU
* Memory
* VGA driver
* USB keyboard input

This computer is designed to run on both a BASYS2 board and 
a NEXYS4DDR board, both from Digilent.

You can see more about its features here: [Rockwell Retro Encabulator
](https://www.youtube.com/watch?v=RXJKdh1KZ0w&t=) (That was a joke ...)

The different parts are connected to a common bus using a wishbone interface,
with the CPU acting as a bus master.

Why? Because:
* This is a learning project.
* It is simple enough to be do-able, and yet useful enough to be interesting.
* I used to own a Commodore 64, and have programmed extensively in 6502 assembler
* There is a C-compiler, [https://github.com/cc65/cc65](cc65), for the 6502.


## The 6502 processor
This is an 8-bit processor with 16-bit address bus.  Memory is accessed in
little-endian format.  I/O is accessed through memory-mapped addresses.
It has three 8-bit registers, one 8-bit stack pointer, and one 16-bit program
counter.

Instructions consist of a 1-byte opcode, followed by zero, one, or two byte
operands.

The instruction decoding is described here:
[http://axis.llx.com/~nparker/a2/opcodes.html](http://axis.llx.com/~nparker/a2/opcodes.html)

Features implemented are:
* ALU
* Interrupt

Feature not (yet) implemented are:
* TBD

Note: Compared to modern standards, this CPU is very inefficient in that it
only has very few registers.  Therefore programs have to use RAM instead of
registers to do calculations, which makes the programs slower. A future project
might implement a different CPU with a larger number of internal registers.

A C-program emulating the 6502 processor can be found here:
[http://rubbermallet.org/fake6502.c](http://rubbermallet.org/fake6502.c)


## Memory
The BASYS2 board (XC3S250E FPGA from Xilinx) has only a limited amount of
memory (24 kB of synchronous Block RAM and 4 kB of asynchronous Distributed
RAM).  Therefore, only a small amount of memory is supported for the entire
computer.

The NEXYS4DDR board has external DDR memory, but this will not be used.


## The VGA driver
As written above, the BASYS2 board has limited memory resources. Therefore, the
VGA driver supports a 40x18 character display together with four sprites (16x16
pixels).
The total memory used by the VGA driver is about 4 kB of Block RAM.


## USB keyboard input

