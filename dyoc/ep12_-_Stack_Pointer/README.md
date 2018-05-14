# Design Your Own Computer - Episode 12 - "Stack Pointer"

Welcome to "Design Your Own Computer".  In this episode we will introduce the
stack pointer, thus allowing for subroutine calls.

The 6502 processor has a fixed stack region of 256 bytes in the memory
range 0x0100 to 0x01FF, and an associated 8-bit Stack Pointer. This requires
a numnber of additions to the Data Path and the Control Logic.

Instructions implemented in total : 45/151.

## Datapath

The Stack Pointer itself can either increase or decrease by one. This is easily
implemented in lines 134-147. There is an associated new control signal
sr\_sel.

Being able to read from and write to the stack region requires writing the
address to the bus. This is handled in line 201. It has become necessary to
increase the size of the control signal addr\_sel.

The instruction RTS requires adding 1 to the 16-bit value read from the
stack region. There, this requires a unique value of pc\_sel, which in
turn requires expanding this control signal too. This is handled in line 103.

The instruction PHP requires writing the value of the Status Register to the
stack.  This is handled by line 206. And the instruction JSR requires writing
both the high and low byte of the Program Counter. This is handled by lines
207-208.  Here too it has become necessary to expand the size of the control
signal data\_sel.

Finally, the instruction PLP requires copying the data input to the Status
Register.  This is handled in line 157.

## Control Logic
We need to add the new control signal sp\_sel in lines 20, 99, and 2719.  Some
of the existing control signals have been expanded, thus changing lines 29-99,
as well as lines 2723-2724. And then the six new instructions are ready to be
implemented!

## Test Program
From now on it will be customary to enhance the test program mem/rom.s with a
small self-validating program to test all the instructions implemented so far.
This will also help catch any regression errors, i.e. changes that break the
previously implemented instructions.

