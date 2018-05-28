# Design Your Own Computer
# Episode 16 : "Indirect Addressing"

Welcome to "Design Your Own Computer".  In this episode we will introduce the
indirect addressing modes, i.e. the "(d,X)" and "(d),Y" instructions.

Instructions implemented in total : 148/151.

## (d,X)
In the first two clock cycles, the instruction is read, and the zero page address
is stored in a new "zero-page" register. In the third cycle, the X register
is added to this zero-page register.
In cycles four and five, two more reads are performed from the address in the
zero-page register. The result is stored in the hold register. This new
address is used for the remainder of the instruction

## (d),Y
In the first two clock cycles, the instruction is read, and the zero page
address is stored in a new "zero-page" register.  In the third and fourth
cycle, two reads are performed from the address in the zero-page register.  The
result is stored in the hold register.  In the fifth clock cycle the
'Y'-register is added to the address in the hold register.  This new address is
used for the remainder of the instruction.

