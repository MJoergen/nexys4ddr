# Design Your Own Computer - Episode 8 - "ALU"

Welcome to the eigth episode of "Design Your Own Computer". In this episode
we will add the Arithmetic and Logic Unit to the CPU.

## Instructions using the ALU
A lot of instructions in the 6502 CPU use the ALU. For instance, looking at the
following list:
* 0D ORA a
* 2D AND a
* 4D EOR a
* 6D ADC a
* 8D STA a
* AD LDA a
* CD CMP a
* ED SBC a

There is a similar list of instructions taking an immediate operand:
* 09 ORA #
* 29 AND #
* 49 EOR #
* 69 ADC #
* 89 Reserved
* A9 LDA #
* C9 CMP #
* E9 SBC #

All these instructions take the 'A' register and the value read from memory,
combines the two operands using some operation and writes the result to the 'A'
register. The only exception is the "STA a" operation that writes the result to
the memory address instead.

## Changes to cpu/datapath.vhd

We will implement those instructions by inserting the ALU in the path from
data input to the 'A' register. In other words, instead of taking data from the
memory input, it will take data from the ALU.

## Status register
The CPU contains an 8-bit status register containing a number of flags. These
are:
0. Carry
1. Zero
2. Interrupt Mask
3. Decimal Mode
4. Break
5. Reserved
6. Overflow (V)
7. Sign

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

## Testing
Note that the CPU has no way of adding two numbers *without* carry. So 
instead some other means of clearing the carry flag is needed. For now,
we'll do it by the sequence "LDA #0" followed by "ADC #0". These two
instructions essentially move the carry flag to the 'A' register, and
clearing the carry flag.

