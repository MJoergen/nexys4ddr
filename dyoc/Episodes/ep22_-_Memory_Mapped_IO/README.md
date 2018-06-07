# Design Your Own Computer
# Episode 22 : "Memory Mapped I/O"

Welcome to "Design Your Own Computer".  In this episode we'll add the option to
have memory mapped I/O. This will be necessary to handle e.g. reading from
keyboard.

However, before we implement the keyboard handling, we'll start with what we
already have: the VGA output, and we'll use it to generate cool graphical
effects.

## VGA memory mapped I/O
The use of memory mapped I/O is to allow the CPU access to read from and write
to a separate module, via ordinary reads from and writes to memory. We already
have something similar in the form of the character and colour memories.

Writing to the VGA module could e.g. control the background colour of the
character screen or the foreground colour of the overlay screen.

Reading from the VGA module could be the current pixel coordinates.

## Clock cycle counter
Another small feature I've added is a 32-bit clock cycle counter. This
can be used to perform precise timing calculations. Not sure it will be
needed, but it's a small feature to implement.

## Addressing
Since only a few bytes of data is transferred between the CPU and the VGA
module, we'll reserve a total of sixty four bytes, half of which are read-only.
We'll place these bytes in the addressable range 7FC0 - 7FFF.

We therefore choose the following addressable locations:
* 7FC0 - 7FCF : VGA Colour palette
* 7FD0 - 7FD1 : VGA Line interrupt
* 7FD2 - 7FDF : Reserved

* 7FE0 - 7FE1 : VGA Pixel X coordinate
* 7FE2 - 7FE3 : VGA Pixel Y coordinate
* 7FE4 - 7FE7 : CPU Clock cycle counter
* 7FE8 - 7FFF : Reserved


## Cool graphical effects :-)
The idea is to change the colour palette synchronuous with the pixel coordinates.

