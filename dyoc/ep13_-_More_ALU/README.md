# Design Your Own Computer - Episode 13 - "More ALU"

Welcome to "Design Your Own Computer".  In this episode we will introduce more
ALU instructions: ASL, ROL, LSR, ROR, DEC, INC, BIT.

Instructions implemented in total : 64/151.

## ALU
The current design of the ALU takes two operarand: The 'A' register and the
memory read data.  The instruction "ASL A" must operate on the 'A' register,
whereas the instruction "ASL a" must operate on the memory data.

In this design I've chosen to have two separate ASL commands to the ALU, one
operating on the first operand, and one operating on the second operand.

