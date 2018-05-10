# Design Your Own Computer - Episode 7 - "Expanding Control Logic"

Welcome to the seventh episode of "Design Your Own Computer". In this episode
we will completely rewrite the Control Logic in a manner that is more readable
and more suited for future expansion.

## Control Logic
Since the control signals are functions of the Instruction Register and of the
Instruction Cycle Counter, it makes sense to implement them in a ROM.

Since an instruction never takes more than eight clock cycles we can easily
calculate the address into this ROM and retrieve all control signals
simultaneously.  This happens in line 2651. Line 2650 is necessary, because
during the first clock cycle of the instruction, the Instruction Register has
not yet been updated.  Since the first cycle is always an instruction fetch
consisting of "read from program counter" and "increment program counter", we
just hard code this value here.

It is useful to define symbols for the values of the different multiplexers in
the datapath. This is done in lines 28-46. The corresponding decoding of the
ROM data into the individual control signals is done in lines 50-57. It is
important that these two sections of the source code are kept in sync. Any
changes to one section will likely need corresponding changes to the other
section.

Using these constants it becomes much easier to write the individual
instructions.  For instance, the "LDA #" instruction is defined in lines
1751-1759. Each line represents one clock cycle.

For many instructions, it is just a matter of deciding the control signals
necessary in each of the up to eight clock cycles. Occasionally, we'll need to
add more control signals, and this entails modifying lines 25-57.

## VGA modification
We've added yet another line of debug output showing the current value of the 
control signals.
