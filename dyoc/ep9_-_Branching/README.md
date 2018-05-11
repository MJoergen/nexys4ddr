# Design Your Own Computer - Episode 9 - "Branching"

Welcome to the nineth episode of "Design Your Own Computer". In this episode
we will perform the following two tasks:
* Add control of individual bits in the status register
* Conditional jumps

## Controlling individual status bits
The 6502 has a number of instructions to manipulate the
status register:
* 18 CLC    (bit 0)
* 38 SEC    (bit 0)
* 58 CLI    (bit 2)
* 78 SET    (bit 2)
* 98    Not related
* B8 CLV    (bit 6)
* D8 CLD    (bit 3)
* F8 SED    (bit 3)

To implement these we need to build upon multiplexer connected to
the status register. And we need to correspondingly expand the selector signal
sr\_sel. This is done in lines 130-149 of cpu/datapath.vhd.

## Conditional jumps
All conditional jumps (branches) on the 6502 are relative to the current
value of the Program Counter. We expand the selector pc\_sel for the Program
Counter and use it in lines 90-116 of cpu/datapath.vhd.
