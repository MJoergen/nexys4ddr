# Design Your Own Computer
# Episode 19 : "C Runtime"

Welcome to "Design Your Own Computer".  In this episode we will modify the
toolchain to support the C runtime, thus allowing us to make C programs run on
the CPU. Furthermore, we will complete the CPU by adding support for Reset.

The C runtime used by the [cc65](http://cc65.github.io/doc/cc65.html) compiler
requires the support of a number of features:
* CPU reset.
* Memory map.
* Linker script.
* Startup code prog/crt0.s

Additionally, we'll perform a few extra steps in this Episode
* Reset button (this is strictly not needed, but a nice feature).
* Cleanup

## CPU reset
Upon reset, the CPU must load the Program Counter from the Reset vector at
address 0xFFFC and 0xFFFD.

To achieve this the control registers must be given default values. Lines
2773-2775 starts the Reset sequence by forcing the Instruction Register to the
value 00.  Lines 2753-2755 skip the first few cycles of the BRK instruction, so
the CPU immediately fetches the Program Counter from the Reset vector.  In
lines 2790-2792 we reset the Invalid Instruction register, but this is just for
debugging purposes. Finally in lines 2814-2816 we instruct the Control Logic
that this is a Reset (as opposed to a regular BRK instruction).

## Memory map (segments)
Even though the memory map of the computer is unchanged, the C runtime
assumes the presence of a number of additional segments. The reason is that
these segments must be placed in different locations in memory,
and have different needs for initialization at startup.

### Segment VECTORS
The segment VECTORS is just six bytes long and holds the addresses of the three
interrupt vectors Reset, NMI, and IRQ. These six bytes must be placed at 0xFFFA.
This segment is defined in the file prog/vectors.s, and we see that the three vectors
point to \_nmi, \_init, and \_irq, respectively. This segment must be part of the ROM.

The ordering of lines 6-8 in prog/vectors.s is crucial.

### Segment CODE
This contains the machine code instructions, i.e. the runnable program. This must
be placed in the ROM.

### Segment DATA
This contains initialized variables. The variables themselves are located in RAM, but
the initial values are stored in the ROM. At startup, these initial values must be
copied from ROM to RAM.

### Segment BSS
This contains uninitialized variables. They must be placed in RAM, and they must
be cleared at startup.

### Segment RODATA
This contains initialized constants. They must be placed in ROM.


## The linker script ld.cfg
This script is taken from from <https://cc65.github.io/doc/customizing.html>
and modified slightly.  Refer to the documentation at
<http://cc65.github.io/doc/ld65.html> for full details.

Other than placing the segments correctly in memory, the linker script additionally
defined extra symbols that are accessible to the startup code, see e.g.
lines 32 and 37 of ld.cfg.

In lines 74-79 of ld.cfg is defined the symbol \_\_STACKSIZE\_\_. This is
because the C runtime uses its own stack space in RAM (as opposed to the
processor stack in page 1). This is because the stack is used to pass arguments
to functions and these arguments can have arbitrary sizes.


## Startup code prog/crt0.s
This code implements the function \_init, which is referenced in the prog/vectors.s
file. The main responsibility is to initialize the DATA segment, clear the BSS segment,
setup the C program stack, and then call the main() function.


## Reset button
It can be useful to reset the CPU after startup.  To this end we use the
CPU\_RESETN button on the Nexys4DDR board and connect it to a new pin 'rstn\_i'
to the computer.  This happens in line 27 of comp.vhd and line 34 of comp.xdc.
Since this button is inverted, we invert the signal in lines 79-87 of comp.vhd.

Note the use of a register (i.e. a synchronous process). This is to ensure
that after power-up the rst signal is automatically asserted (i.e. by using
the default value assigned in line 42 of comp.vhd).

## Cleanup
We can now get rid of the default value of the Program Counter in line 146 of
cpu/datapath.vhd. Furthermore, I've removed the CIC module and the file
mem/cic.vhd, since that was just for testing purposes in the previous episode.
Additionally, writing to the ROM is removed as well.

