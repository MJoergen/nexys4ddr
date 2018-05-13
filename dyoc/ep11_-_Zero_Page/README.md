# Design Your Own Computer - Episode 11 - "Zero Page"

Welcome to "Design Your Own Computer".  In this episode we will make introduce
the memory map of the CPU and add some more instructions.

## Memory map
So far we have a single memory starting from address 0x0000, and the Program
Counter has been initialized to 0x0000 upon startup. However, on the 6502
processor, the adress range 0x0000 - 0x00FF is reserved for "Zero Page
Registers". These are registers that reside in memory, but may be accessed (one
clock cycle) faster than regular memory, because the instructions are one byte
shorter.

The machine code that the CPU executes will reside in the upper end of memory,
i.e.  up to 0xFFFF. So we'll now introduce the concept of *memory map*, which
is a division of the total addressable range 0x0000 - 0xFFFF into chunks with
different purposes.

In the low range we'll have 2K bytes of RAM, i.e. from 0x0000 - 0x7FFF. And in
the high end we'll have 2K bytes of ROM, i.e. from 0xF800 - 0xFFFF. The
remaining (60K bytes) will for now be unused. However, we'll later add video
memory, allowing the CPU to write text on the screen.

Thus, we'll now have two memory blocks (RAM and ROM), and where ROM will be
initialized from a file. We need to write address coding to determine which of
the two memory blocks (if any) the CPU is accessing.

We need to change the initial value of the Program Counter. This is temporary
solution, and in a later episode we'll finally implement the correct way of
initializing the Program Counter.

## Zero Page
This is surprisingly easy. The only thing to change in cpu/datapath.vhd is to
add the option of hardcoding the upper bits to zero. This is done in line 180,
and the corresponding control signal is added in line 52 in cpu/ctl.vhd.

## Testing
The CPU is reaching a complexity level where it is useful to have some
automated way of testing the implementation. The file mem/rom.s now contains a
self-verifying assembly program to test the functionality of the CPU. The
program eventually ends in a infinite loop, and the value of the 'A' register
will be the result of the test.  The value "FF" corresponds to success,
anything else is a failure.
