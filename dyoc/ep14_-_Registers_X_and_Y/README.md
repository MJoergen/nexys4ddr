# Design Your Own Computer - Episode 14 - "Registers X and Y"

Welcome to "Design Your Own Computer".  In this episode we will introduce the
two registers X and Y, and the associated instructions.

Instructions implemented in total : ??/151.

All the instructions we'll be implementing in this episode are:
STX, LDX, CPX, INX, DEX, TAX, TXA, TSX, TXS

All these instructions modify the flags (except STX and TXS). That means the
X-register takes it's value from the ALU, just like the 'A'-register.

We introduce two new control signals:
* xr\_sel : Whether to update the 'X' register with the output of the ALU
* reg\_sel : Which register (AR, XR, YR, SP) to send the operand A of the ALU.

The above will take care of STX, LDX, and CPX.

To deal with TXA, 

* 8A TXA
* 9A TXS
* AA TAX
* BA TSX
* CA DEX
* E8 INX

And similarly for the 'Y' register (except for TSX and TXS).

The challenging part here is that we would like to reuse the hardware
resources, notably the ALU. The reason is the similarity betweenb instructions,
particularly (CMP / CPX) and (LDA / LDX).  These instructions must set the
status register flags too.

