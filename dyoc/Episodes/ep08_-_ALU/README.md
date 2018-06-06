# Design Your Own Computer
# Episode 8 : "ALU"

Welcome to the eigth episode of "Design Your Own Computer". In this episode
we will add the Arithmetic and Logic Unit to the CPU.

Instructions implemented in total : 16/151.

## Instructions using the ALU
A lot of instructions in the 6502 CPU use the ALU, for instance the following
list all using absolute addressing:
* 0D : ORA a
* 2D : AND a
* 4D : EOR a
* 6D : ADC a
* 8D : STA a
* AD : LDA a
* CD : CMP a
* ED : SBC a

There is a similar list of instructions taking an immediate operand:
* 09 : ORA #
* 29 : AND #
* 49 : EOR #
* 69 : ADC #
* 89 : Reserved
* A9 : LDA #
* C9 : CMP #
* E9 : SBC #

All these instructions take the 'A' register and the value read from memory,
combines the two operands using some operation and writes the result to the 'A'
register. The only exception is the "STA" operation that writes the result to
the memory address instead.

The ALU is implemented in a separate file cpu/alu.vhd. It takes as input the
two operands as well as the function code (which operation to perform) and
outputs the result. The ALU is entirely combinatorial, and essentially consists
of a large multiplexer selecting between the eight different operations.

## Status register
The CPU contains an 8-bit status register containing a number of flags. These
are:

0. Carry (C)
1. Zero (Z)
2. Interrupt Mask (I)
3. Decimal Mode (D)
4. Break (B)
5. Reserved
6. Overflow (V)
7. Sign (S)

Some of these flags (C, Z, V, and S) store the result of the last operation,
and are therefore calculated in the ALU. The remaining three (I, D, and B) are
processor modes, which we will leave for a later episode.

Not all ALU operations modify all the four flags. The list is as follows:
* ORA : S,Z
* AND : S,Z
* EOR : S,Z
* ADC : S,Z,C,V
* STA : none
* LDA : S,Z
* CMP : S,Z,C
* SBC : S,Z,C,V

## Changes to cpu/datapath.vhd

We will implement the above instructions by inserting the ALU in the path from
data input to the 'A' register. In other words, instead of taking data from the
memory input, it will take data from the ALU. This changes the single line 103.

The Status Register is defined in lines 55-56 and controlled in lines
109-119.

The output from the ALU is routed to two new signals alu\_ar and alu\_sr
defined in lines 45-47.

The ALU itself is instantiated in lines 71-80.

## Testing
Note that the CPU has no way of adding two numbers *without* carry. So instead
some other means of clearing the carry flag is needed. For now, we'll do it by
the sequence "LDA #0" followed by "ADC #0". These two instructions essentially
move the carry flag to the 'A' register, and clears the carry flag.

The program defined in lines 43-55 of mem/mem.vhd is a simple 8-bit counter.

Note that the memory size has been increased from 16 bytes to 256 bytes. This
was done in lines 111 and 115 in comp.vhd.

