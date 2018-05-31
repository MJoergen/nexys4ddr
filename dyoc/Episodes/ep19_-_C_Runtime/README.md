# Design Your Own Computer
# Episode 19 : "C Runtime"

Welcome to "Design Your Own Computer".  In this episode we will modify the
toolchain to support the C runtime, thus allowing us to make C programs run on
the CPU. Furthermore, we will complete the CPU by adding support for Reset.

## Implementing Reset
From now on, the CPU will upon reset load the Program Counter from the Reset
vector at address 0xFFFC and 0xFFFD. To this end we use the CPU\_RESETN button
on the Nexys4DDR board and connect it to a new pin 'rstn\_i' to the computer.
This happens in line 27 of comp.vhd and line 34 of comp.xdc. Since this button
is inverted, we invert the signal in lines 79-87 of comp.vhd.

Note the use of a register (i.e. a synchronous process). This is to ensure
that after power-up the rst signal is automatically asserted (i.e. by using
the default value assigned in line 42 of comp.vhd).

Upon reset the control registers must be given default values. Lines 2773-2775
starts the Reset sequence by forcing the Instruction Register to the value 00.
Lines 2753-2755 skip the first few cycles of the BRK instruction, so the CPU
immediately fetches the Program Counter from the Reset vector.
In lines 2790-2792 we reset the Invalid Instruction register, but this is
just for debugging purposes. Finally in lines 2814-2816 we instruct the Control
Logic that this is a Reset (as opposed to a regular BRK instruction).

## The linker script ld.cfg
The linker script is completely changed now, and the implementation is taken
from <https://cc65.github.io/doc/customizing.html> and modified slightly.
Refer to the documentation at <http://cc65.github.io/doc/ld65.html> for full
details.

Even though the memory map of the computer is unchanged, the C runtime support
assumes the presence of a number of additional segments. For instance, the
segment VECTORS is just six bytes long but holds the addresses of the three
interrupt vectors Reset, NMI, and IRQ. These six bytes must be placed at the
correct address, and this is indicated in lines 55-58 of ld.cfg.  The file
prog/vectors.s defines these six bytes based on imported symbols, and places
these bytes in the VECTORS segment. The ordering of lines 6-8 in prog/vectors.s
is crucial.

In lines 74-79 of ld.cfg is defined the symbol \_\_STACKSIZE\_\_. This is
because the C runtime uses its own stack space in RAM (as opposed to the
processor stack in page 1). This is because the stack is used to pass arguments
to functions and these arguments can have arbitrary sizes.

The segments DATA, BSS, and RODATA contain, respectively, initialized variables,
uninitialized variables, and constants. Furthermore, lines 32 and 37 of ld.cfg
instructs the linker to define symbols containing the address and size of these
segments. These symbols are used by the start-up code, see next section.

## Startup code prog/crt0.s
After reset, the C runtime environment has to be setup. For instance, the
variables in the DATA segment need to be initialized.  The Reset vector in
prog/vectors.s points to the symbol \_init, which is implemented in line 18 of
prog/crt0.s. These few assembly instructions suffice to setup the C runtime,
and control is passed to the C program function main() in line 42 of
prog/crt0.s.

## Cleanup
We can now get rid of the default value of the Program Counter in line 146 of
cpu/datapath.vhd. Furthermore, I've removed the CIC module and the file
mem/cic.vhd, since that was just for testing purposes in the previous episode.
Additionally, writing to the ROM is removed as well.

