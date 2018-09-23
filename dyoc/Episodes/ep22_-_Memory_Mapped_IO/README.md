# Design Your Own Computer
# Episode 22 : "Memory Mapped I/O"

Welcome to "Design Your Own Computer".  In this episode we'll add the option to
have memory mapped I/O, which is used to transfer data between the CPU and any
peripheral devices like e.g. the keyboard.  We'll also use the memory mapped
I/O to configure the colour palette of the VGA output.

## Addressing
Since only a few bytes of data is transferred between the CPU and the peripheral
devices, we'll reserve a total of sixty four bytes, half of which are read-only.
We'll place these bytes in the addressable range 7FC0 - 7FFF.

We therefore choose the following writeable data:
* 7FC0 - 7FCF : VGA Colour palette
* 7FD0 - 7FDF : Reserved

and the folowing readonly data:
* 7FE0 - 7FE1 : VGA Pixel X coordinate
* 7FE2 - 7FE3 : VGA Pixel Y coordinate
* 7FE4 - 7FE7 : CPU Clock cycle counter
* 7FE8 - 7FFF : Reserved

Note that the Memory Mapped IO address range collides with the RAM address range.
This effectively means that we can't use the last 64 bytes of the 32 Kbyte RAM.
However, we must be careful to establish the correct priority. So in
mem/mem.vhd lines 201-206, it is important that memio comes before ram, to
ensure the CPU reads from the Memory Mapped IO and not from the RAM.
Furthermore, we must instruct the C runtime library that these bytes of RAM are
unavailable. This is done in line 15 of prog/ld.cfg.

The Memory Map is implemented in mem/memio.vhd, but the actual memory map is
inferred from the connections in lines 219-235 in fpga/comp.vhd.

## VGA memory mapped I/O
The colour palette consists of 16 bytes, where the byte at address 7FC0 maps to
the colour index 0, and the byte at address 7FCF maps to the colour index 15.
The default values are such that index 0 is black, and index 15 is white. The colour
memory is initialized to white on black, i.e. index 15 in foreground and index 0 in
background.

Therefore, by writing to address 7FC0 the CPU can control the default background
colour of the screen. This will be used to generate cool graphical effects, which
I'll describe in the following.

Reading from the VGA module will be the current pixel coordinates. Note that
these are 16-bit values in little-endian format, with the LSB at the even
addresses and the MSB at the odd addresses. This need not concern the programmer
because the toolchain is setup to do the right thing when accessing the
coordinates through a uint16\_t pointer.


## Clock cycle counter
Another small feature I've added is a 32-bit clock cycle counter. This
can be used to perform precise timing calculations. Not sure it will be
needed, but it's a small feature to implement.


## Cool graphical effects :-)
With just the above, the CPU can create nice horizontal lines on the screen.
The idea is to change the colour palette, i.e. the default background colour,
in a manner synchronous to the current VGA pixel coordinate.

Unfortunately, the VGA output is not quite stable, and there is a substantial
amount of flickering. This is due to the fact that the CPU and the VGA are
not synchronized. This will be solved in the next episode.

