# Design Your Own Computer
# Episode 15 : "Indexed Addressing"

Welcome to "Design Your Own Computer".  In this episode we will introduce the
indexed addressing modes, i.e. alle the "a,X", "a,Y", "d,X", and "d,Y" instructions.

Instructions implemented in total : 132/151.

## LDA a,X and LDA a,Y
In these instructions we must read the absolute address in the second and third
cycles.  Then in the fourth cycle we must add either the 'X' or 'Y' register to
this address, and then proceed as with the usual LDA a.

We use the HI and LO registers, and introduce some temporary signals:
hilo\_addx\_s and hilo\_addy\_s. The trailing '\_s' is a naming convention to
convey that the signals is combinatorial, i.e. NOT directly connected to a
register (flip-flop).
