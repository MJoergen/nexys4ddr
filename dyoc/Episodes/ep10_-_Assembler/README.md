# Design Your Own Computer
# Episode 10 : "Assembler"

Welcome to the tenth episode of "Design Your Own Computer".  In this episode we
will make use of an assembler to generate the initial contents of the memory.

Instructions implemented in total : 31/151.

The assembler and linker are part of a toolchain for the 6502 CPU, which can be
found here: <https://github.com/cc65/cc65>.

The assembler source file is in main/mem/ram.s. This is essentially the same program
as in the previous episode, except the memory has been expanded to 1K bytes.

The assembler file is first translated by the assembler using the command
[ca65](http://cc65.github.io/doc/ca65.html). This generates an object file
mem/mem.o.

Then the object file is linked using the linker
[ld65](http://cc65.github.io/doc/ld65.html) in conjunction with the linker
script in ld.cfg. This will generate a binary file with the initial contents of
the memory.

The Xilinx tools require a text file, so the binary file is translated using
the python script bin2hex.py. This generates a file mem/mem.txt, that can be
loaded by the Xilinx tool as the initial contents of the memory.

And that is it! Now you can write programs directly in assembly in the file
main/mem/ram.s, and have the CPU execute the program. We are still a long way from
writing programs in C, because the C-compiler will most likely make use
of some of the many instructions we've not yet implemented.

We still have some way to go before we can actually do anything interesting
with this computer. In the next episode we'll add some more instructions and
go into details about the memory map.

