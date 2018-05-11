# Design Your Own Computer - Episode 10 - "Assembler"

Welcome to the tenth episode of "Design Your Own Computer".
In this episode we will make use of an assembler to
generate the initial contents of the memory.

The assembler and linker are part of a toolchain for the 6502 
CPU, which can be found here: <https://github.com/cc65/cc65>.

The assembler source file is in mem/mem.s. This is essentially
the same program as in the previous episode, except the memory
has been expanded to 1K bytes.

The assembler file is first translated by the assembler using
the command *ca65*. This generates an object file mem/mem.o.

Then the object file is linked using the linker *ld65* in
conjunction with the linker script in ld.cfg. This will 
generate a binary file with the initial contents of the memory.

The Xilinx tools require a text file, so the binary file is
translated using the python script bin2hex.py. This generates a
file mem/mem.txt, that can be loaded by the Xilinx tool as 
the initial contents of the memory.
