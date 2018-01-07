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


## The MC68000 processor
This is a RISC processor with 32-bit data bus and 16-bit address bus.

Features implemented are:
* Integer ALU

Feature not (yet) implemented are:
* Floating Point Unit
* Supervisor mode
* Interrupt

More information about this processor can be found here:
[https://www.nxp.com/docs/en/reference-manual/MC68000UM.pdf](https://www.nxp.com/docs/en/reference-manual/MC68000UM.pdf)


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

