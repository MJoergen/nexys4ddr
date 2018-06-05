# Design Your Own Computer
# Episode 22 : "Memory Mapped I/O"

Welcome to "Design Your Own Computer".  In this episode we'll add the option to
have memory mapped I/O. This will be necessary to handle reading from keyboard.

However, before we implement the keyboard handling, we'll start with what we
already have: the VGA output, annd we'll use it to generate cool graphical
effects.

## VGA memory mapped I/O
The use of memory mapped I/O is to allow the CPU access to read from and write
to a separate module, via ordinary reads from and writes to memory. We already
have something similar in the form of the character and colour memories.

Writing to the VGA module could e.g. control the background colour of the
character screen, as well as the foreground and background colours of the
overlay screen.

Reading from the VGA module could be the current pixel coordinates.

## Addressing
Since only a few bytes of data is transferred between the CPU and the VGA
module, we'll reserve a total of sixteen bytes, half of which is read-only.
We'll place the sixteen bytes in the addressable range 7FF0 - 7FFF.

We therefore choose the following addressable locations:
* 7FF0 : character background colour
* 7FF1 : overlay foreground colour
* 7FF8 : pix\_x low  (read-only)
* 7FF9 : pix\_x high (read-only)
* 7FFA : pix\_y low  (read-only)
* 7FFB : pix\_y high (read-only)

## Cool graphical effects :-)
The idea is to change the background colour synchronuous with the pixel coordinates.

