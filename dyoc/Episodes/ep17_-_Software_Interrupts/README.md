# Design Your Own Computer
# Episode 17 : "Software Interrupts"

Welcome to "Design Your Own Computer".  In this episode we will implement
the three remaining instructions: JMP (a), BRK, and RTI. Furthermore,
we'll introduce a more thorough functional test of the entire CPU.

Instructions implemented in total : 151/151.

## 6C JMP (a)
In this instruction, we read the new value of the Program Counter
in cycles 4 and 5. We therefore need two new values for pc\_sel, see
lines 220-221 in cpu/datapath.vhd. Additionally, we need the ability
to increment the address in the hold registers. This is done in
lines 316 and 333. The control signals hi\_sel and lo\_sel need to be
expanded to cover this new functionality.

## 00 BRK
This instruction is a bit tricky, since it is actually a two-byte instruction,
even though the second byte is not used. The Program Counter value stored on
the stack is the address after the second byte, so the Program Counter needs to
be incremented twice, before the value is stored onto the stack. This accounts
for the line 159 in cpu/ctl.vhd

Furthermore, the Break bit in the Status Register must be set before it is
pushed onto the stack, but the value itself in the Status Register is not
changed. Since the same functionality is already implemented for the PHP
insttruction, no additional changes are needed for this.

Finally, we need to read the new Program Counter from the hardware vectors.
This requires adding the lines 363-368 in cpu/datapath.vhd, as well as
increasing the size of the addr\_sel control signal. Here we've added
partial support for the NMI and RESET vectors too, even though they won't
be fully implemented in this episode.


## 40 RTI
No changes to the datapath is needed to implement this instruction.


## Functional test
In a different project (<https://github.com/Klaus2m5/6502_65C02_functional_tests>)
I've found a very thorough functional test of the entire CPU
instruction set.  Unfortunately, the assembly syntax is not compatible with the
ca65 assembler, so it has been necessary to do a lot a manual editing,
including:
* Insert '.' in front of assembler commands like .if and .endif
* Appending ':' after all labels.
* Replacing 'db' with '.byt' and 'dw' with '.addr'.
* Plus a few other changes.

The size of the ROM needs to be expanded, because of the size of the functional
test. This means changing the initial value of the Program Counter
in line 142 in cpu/datapath.vhd, as well as changes to mem/mem.vhd.

It was also necessary to allow write access to the ROM, because the test
requires this.  This is done in lines 71-79 in mem/rom.vhd, as well as lines
77-78 in mem/mem.vhd.

The complete functional test runs in about 3 seconds at the 25 MHz clock rate,
i.e. consuming approximately 75 million clock cycles. It therefore becomes
necessary to run the CPU at the maximum possible speed. This is achieved by
re-defining bit 7 of the input switch to denote "full speed".  This is easily
achieved by changing line 86 in comp.vhd, so that mem\_wait is never asserted
at full speed.

