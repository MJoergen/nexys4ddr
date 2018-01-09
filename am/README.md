# Ask-Michael (AM) computer

This is a computer built around a (partial) implementation of
the MC68000 processor.
The computer consists of the following parts:
* MC68000 CPU
* Memory
* VGA driver
* USB keyboard input

This computer is designed to run on both a BASYS2 board and 
a NEXYS4DDR board, both from Digilent.

You can see more about its features here: [Rockwell Retro Encabulator
](https://www.youtube.com/watch?v=RXJKdh1KZ0w&t=) (That was a joke ...)


## The MC68000 processor
This is a processor with 16-bit data bus and 24-bit address bus. It has
sixteen internal 32-bit registers. Memory is accessed in big-endian format.
I/O is accessed through memory-mapped addresses.

Features implemented are:
* Integer ALU
* Interrupt (section 5.1.4 and 6.3.2)

Feature not (yet) implemented are:
* Test and set (TAS) read-modify-write (section 5.1.3)
* Bus arbitration (sections 5.2 and 5.3 and 5.4 and 5.6)
* Reset operation (section 5.5)
* Supervisor mode and exceptions (section 6)
* Floating Point Unit

More information about this processor can be found here:
[https://www.nxp.com/docs/en/reference-manual/MC68000UM.pdf](https://www.nxp.com/docs/en/reference-manual/MC68000UM.pdf)
Detailed description of the instruction set is here:
[https://www.nxp.com/docs/en/reference-manual/M68000PRM.pdf](https://www.nxp.com/docs/en/reference-manual/M68000PRM.pdf)


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

