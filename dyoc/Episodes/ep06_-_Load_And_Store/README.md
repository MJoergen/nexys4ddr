# Design Your Own Computer
# Episode 6 : "Load and Store"

Welcome to the sixth episode of "Design Your Own Computer". In this episode we
will add three more instructions to the CPU: "LDA a", "STA a", and "JMP a".
All three instructions make use of absolute addressing. I.e. all instructions
are three bytes long and consist of 1 byte opcode followed by a 2 byte address
with the lower 8 bits first, and the upper 8 bits last. This is known as
"little-endian".

We will make a number of modifications to the datapath and the control logic.

Instructions implemented in total : 4/151.

## Datapath

In the following we will discuss the modifications necessary to cpu/datapath.vhd
in order to allow the CPU to execute the three new instructions.

### LDA a
When executing the "LDA a" instruction the CPU first spends three clock cycles
reading the three bytes of the instruction. On the fourth clock cycle the CPU
will then perform a read from memory.  The address in memory the CPU reads from
is given as the second and third byte of the instruction.  These two bytes must
be stored somewhere within the CPU, and for that purpose we introduce two new
internal registers: HI and LO. They receive data from the data input pins, but -
just like the 'A' register - only update when told to. So we therefore
introduce two control signals, hi\_sel and lo\_sel too.

The address output can now take one of two possible values: Either the current
value of the Program Counter, or the value of the HI and LO registers. We
therefore introduce a multiplexer in lines 147-150, as well as yet another
control signal: addr\_sel.

Furthermore, during the fourth clock cycle, the Program Counter should not be
incremented.  We therefore introduce another control signal pc\_sel to allow
the Program Counter to keep the same value in this current clock cycle.

### STA a
The "STA a" instructions is very similar to the "LDA a" instruction, and
differs only in the last (fourth) clock cycle.  When doing "STA a" the 'A'
register must be copied to the data output signals, and the wren signal must be
set to '1'. This is done in lines 152-157, and once again a new control
signal data\_sel is introduced.

### JMP a
Once again, this instruction differs only from the previous two in the final
(fourth) clock cycle.  In this case, the value of the HI and LO registers are
to be copied to the Program Counter.  This only requires a small addition to
the multiplexer in front of the Program Counter.

## Control logic
All the control signals mentioned above must be given valid values in all clock
cycles of all instructions. The design is made such that a value of 0 for a
control signal has no effect, i.e.  a "no operation".

All the control signals are generated in lines 62-94 of cpu/ctl.vhd.

In the next episode we'll see how to implement the control logic in a manner
that is easier to read and to maintain.

