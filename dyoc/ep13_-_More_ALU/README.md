# Design Your Own Computer - Episode 13 - "More ALU"

Welcome to "Design Your Own Computer".  In this episode we will introduce more
ALU instructions: ASL, ROL, LSR, ROR, DEC, INC, BIT.

Instructions implemented in total : 64/151.

## ALU
The current design of the ALU takes two operarand: The 'A' register and the
memory read data.  The instruction "ASL A" must operate on the 'A' register
(i.e. the first operand), whereas the instruction "ASL a" must operate on the
memory data (i.e. the second operand).

In this design I've chosen to have two separate ASL commands to the ALU, one
operating on the first operand, and one operating on the second operand.

## Moving forward
The remaining instructions involve the remaining two registers 'X' and 'Y', and
the corresponding addressing modes. This will be the topic for the next two
episodes.  There still remains three instructions: BRK, RTI, and JMP (a). The
first two involve the concept of interrupts. We'll return to these after having
worked some more on the VGA module.

