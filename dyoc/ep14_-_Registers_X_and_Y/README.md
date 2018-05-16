# Design Your Own Computer - Episode 14 - "Registers X and Y"

Welcome to "Design Your Own Computer".  In this episode we will introduce the
two registers X and Y, and the associated instructions.

Instructions implemented in total : 90/151.

The instructions we'll be implementing in this episode are:
STX, LDX, CPX, INX, DEX, TAX, TXA, TSX, TXS, and the corresponding for the 'Y'
register.

All these instructions modify the flags (except STX and TXS). That means the
X-register takes it's value from the ALU, just like the 'A'-register.

We introduce three new control signals:
* xr\_sel : Whether to update the 'X' register with the output of the ALU
* yr\_sel : Whether to update the 'Y' register with the output of the ALU
* reg\_sel : Which register (AR, XR, YR, SP) to send to the first operand of
  the ALU.

The above will take care of STX, LDX, and CPX.

To deal with TXA, we need the ALU to output the first operand, but also update
the flags. So we introduce a new ALU function LDA\_A, which does just that.

