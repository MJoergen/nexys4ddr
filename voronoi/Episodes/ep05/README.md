# Episode 5 : Improving the movement of the Voronoi points.

Welcome to this fifth episode of the tutorial. In this episode, we will
improve the movement of the Voronoi points.

We will do this by having each point move with its own different velocity.

Most of the change is in the file move.vhd. Two more generics are added to
initialize the velocity. The internal representation of the coordinates is
changed to a 10.3 fixed point fractional value. So the coordinates now have 13
bits, where the upper 10 bits are the integer part, and the lower 3 bits are
the fractional part.

The velocity is given in 1.3 fixed point two's complement. This means four bits
are used to represent fractional values between -1 and +1, with a step size of 0.125.
We have the following examples:

* "1000" -> -1.0
* "1100" -> -0.5
* "1111" -> -0.125
* "0000" -> 0.0
* "0100" -> 0.5
* "0111" -> 0.875

## Bugfix.
I noticed a bug where a thin vertical line was shown to the left of the screen.
This was due to a mismatch in the timing of the synchronization signals and the
colour signal.  I've therefore removed the register on the synchronization
signals in the file vga.vhd, and added some registers in the file voronoi.vhd.


## Future work
There are occasionally some strange visual artifacts, perhaps some rastering
effect, that I would like to resolve.
