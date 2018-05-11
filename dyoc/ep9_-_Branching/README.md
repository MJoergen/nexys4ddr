# Design Your Own Computer - Episode 9 - "Branching"

Welcome to the nineth episode of "Design Your Own Computer". In this episode
we will perform the following two tasks:
* Add control of individual bits in the status register
* Conditional branching

## Controlling individual status bits
The 6502 has a number of instructions to manipulate the
status register:
* 18 CLC    (bit 0)
* 38 SEC    (bit 0)
* 58 CLI    (bit 2)
* 78 SET    (bit 2)
* 98 Not related
* B8 CLV    (bit 6)
* D8 CLD    (bit 3)
* F8 SED    (bit 3)

