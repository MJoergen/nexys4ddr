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
lines 316 and 333.

## 00 BRK
Here we need to read from the hardware vectors.  This requires adding the lines
363-368 in cpu/datapath.vhd.

This instruction is a bit tricky, since it is actually a two-byte instruction,
even though the second byte is not used. The Program Counter value stored on
the stack is the address after the second byte, so the Program Counter needs to
be incremented twice, before the value is stored onto the stack.

Furthermore, the Break bit in the Status Register must be set before it is
pushed onto the stack, but the value itself in the Status Register is not
changed.

## 40 RTI
No changes to the datapath is needed to this instruction.

## Functional test
In a [https://github.com/Klaus2m5/6502_65C02_functional_tests](different
project) I've found a very thorough functional test of the entire CPU
instruction set.
Unfortunately, the assembly syntax is not compatible with the ca65 assembler,
so it has been necessary to do a lot a manual editing. Edits include:
* Insert '.' in front of assembler commands like .if and .endif
* Appending ':' after all labels.

The size of the ROM needs to be expanded, because of the size of the functional
test. This means changing the initial value of the Program Counter
in line 142.

It was also necessary to allow write access to the ROM, because the test requires this.
This is done in lines 71-79 in mem/rom.vhd, as well as lines 77-78 in mem/mem.vhd.

