# Design Your Own Computer
# Episode 19 : "C Runtime"

Welcome to this - rather lengthy - nineteenth episode of "Design Your Own
Computer".

Let's first take a status of the project. So far we've finished implementing
the 6502 CPU. That means we can now write programs (in assembly, using the
assembler [ca65](http://cc65.github.io/doc/ca65.html)) and have them run of our
computer.

We still need to expand the functionality of the VGA output and add keyboard
input, as well as add an operating system, before our computer is anywhere
near complete.  However, before we do that, I would like to be able to run
C-programs on our computer, instead of having to write them in assembly.

Being able to run C-programs on our computer requires several additions to
our tool chain:
* C compiler targeting the 6502 CPU.
* C linker.
* C runtime ABI support.
* C runtime library.

As our C compiler I will use [cc65](http://cc65.github.io/doc/cc65.html).  This
compiler comes with a complete toolchain including linker, runtime library, ABI
support, etc.  The toolchain requires the support of a number of features in
our computer that we'll implement in this episode:
* CPU reset.
* Memory map.
* Linker script.
* Startup code.

Additionally, we'll perform a few extra steps in this episode:
* Reset button (this is strictly not needed, but a nice feature).
* Cleanup of the directory structure.

## CPU reset
Upon reset, the CPU must load the Program Counter from the Reset vector at
address 0xFFFC and 0xFFFD, instead of using a hardcoded value in the
source code.

To achieve this the control registers must be given default values.
* Lines 2774-2777 of cpu/ctl.vhd starts the Reset sequence by forcing the
Instruction Register to the value 00, i.e. the BRK instruction.
* Lines 2753-2756 skip the first few cycles of the BRK
instruction, so the CPU immediately fetches the Program Counter from the Reset
vector. In other words it won't write the current (undefined) value of the 
Program Counter to the processor stack, during the Reset operation.
* In lines 2792-2795 we reset the Invalid Instruction register. This
is just for debugging purposes.
* Finally in lines 2817-2820 we instruct the
Control Logic that this is a Reset (as opposed to a regular BRK instruction).

## Memory map (segments)
Even though the memory map of the computer is unchanged, the C runtime assumes
the presence of a number of additional segments. The reason is that these
segments have different requirements for initialization at startup.
The segments are defined in the linker script prog/ld.cfg, and are initialized
in the startup code in prog/lib/crt0.s, see the following sections.

### Segment VECTORS
The segment VECTORS is just six bytes long and holds the addresses of the three
interrupt vectors Reset, NMI, and IRQ. These six bytes must be placed at
0xFFFA.  This segment is defined in the file prog/lib/vectors.s, and we see
that the three vectors point to nmi\_int, init, and irq\_int, respectively.
This segment must be part of the ROM.  The ordering of these lines is crucial.

### Segment CODE
This contains the machine code instructions, i.e. the runnable program. This
must be placed in the ROM.

### Segment DATA
This contains initialized variables. The variables themselves are located in
RAM, but the initial values are stored in the ROM. At startup, these initial
values must be copied from ROM to RAM.

### Segment BSS
This contains uninitialized variables. They must be placed in RAM, and they must
be cleared at startup.

### Segment RODATA
This contains initialized constants. They must be placed in ROM.


## The linker script prog/ld.cfg
This script is taken from <https://cc65.github.io/doc/customizing.html> and
modified slightly.  Refer to the documentation at
<http://cc65.github.io/doc/ld65.html> for full details.

Other than placing the segments correctly in memory, the linker script
additionally defines extra symbols that are used by the startup code, see
e.g.  lines 38, 39, and 47 of prog/ld.cfg.

Lines 97-102 of ld.cfg define the symbol \_\_STACKSIZE\_\_. This is because the
C runtime uses its own stack space in RAM (as opposed to the processor stack at
address 0x0100). This is because the C-stack is used to pass arguments to
functions and these arguments can have arbitrary sizes.


## Startup code prog/lib/crt0.s
Upon reset, the processor starts executing code at the label "init" referenced in
prog/lib/vectors.s. This startup code is placed in a separate file
prog/lib/crt0.s in line 18, and is responsible for setting up the C runtime
environment:
* Setup the processor stack (lines 24-30).
* Initialize the C-stack for function arguments (lines 32-38).
* Clear the BSS segment (line 43).
* Initialize the DATA segment (line 44).
* Call the main() function (lines 47-50).

Upon exit from the main() function, the CPU enters an infinite loop in lines 55-59.

Interrupts (IRQ and NMI) are currently not supported, so they just return immediately,
see lines 61-67.

The startup code references a number of functions, e.g. zerobss and copydata.
These functions must be implemented too. I've chosen to use the existing
runtime libraries provided by the cc65 toolchain. This runtime library
depends on the platform. The platform we're building is basically a bare-metal
platform, no features other than keyboard input and VGA output (both yet to be
implemented). Therefore, we copy the default library from cc65/lib/none.lib to
prog/lib/none.lib. This library contains several useful functions, including zerobss and
copydata, as well as functions to support the cc65 ABI.

This library also contains its own version of the startup code crt0.s, which
must be replaced by our own. This is taken care of in prog/Makefile in lines 23-26,
where we make our own copy of none.lib and modify the copy.


## Reset button
It can be useful to reset the CPU after startup.  To this end we use the
CPU\_RESETN button on the Nexys4DDR board and connect it to a new pin 'rstn\_i'
to the computer.  This happens in line 27 of comp.vhd and line 34 of comp.xdc.
Since this button is inverted, we invert the signal in lines 78-86 of comp.vhd.

Note the use of a register (i.e. a synchronous process). This is to ensure
that after power-up the rst signal is automatically asserted (i.e. by using
the default value assigned in line 42 of comp.vhd).

## Cleanup
The project has now grown to a size where it is convenient to add more
directory structure.  So everything has been distributed to two new directories
fpga/ and prog/. The former contains all the VHDL code and Makefiles necessary
to generate a bit-file. The directory prog/ contains everything needed to
generate the ROM image.

Furthermore, I have removed some unused code, e.g.  the CIC module and the file
mem/cic.vhd, since that was just for testing purposes in the previous episode.
Additionally, writing to the ROM is removed as well.

