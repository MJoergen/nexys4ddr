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

## Supported make targets are:
* make sim : Simulate the computer so far. It uses the functional test
  in mem/mem.s as stimulus.
* make fpga : Program the FPGA and run the computer on the hardware.

The test ends after around 1000 clock cycles with the value $FF in the
A-register and the value $4C in the Instruction Register (executing a JMP
instruction at $FB61).  This corresponds to approx eight seconds
in the hardware, when running with switch 7 set to on.
