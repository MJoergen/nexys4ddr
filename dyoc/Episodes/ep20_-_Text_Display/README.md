# Design Your Own Computer
# Episode 20 : "Text Display"

Welcome to "Design Your Own Computer".  After this episode
the computer will be able to display 80x60 characters on the VGA output.

## Memory map
The screen resolution is 640x480 and since our font is 8x8 this gives a screen
size of 80x60 characters, i.e. 4800 bytes (or 0x12C0 in hexadecimal). For
simplicity we'll allocate 8 Kbytes for the character screen, i.e. 0x2000 bytes.
We'll add colours to each character as well, so that's another 8 Kbytes.

The CPU can access the character memory and the colour memory by
writing to the following address ranges:
0x8000 - 0x92BF : Character memory
0xA000 - 0xB2Bf : Colour memory

Address within 0x8000 - 0xBFFF but outside the above ranges are not used.

The current design will only allow support writing to these memory ranges.
Allowing the CPU to read from these memory ranges will require a rather large
number of additional changes, so that is deferred to the next episode.

By now we have four different active memory ranges (ROM, RAM, CHAR, and COL),
and it is practical to make the design slightly more generic. Therefore, in
mem/mem.vhd we've added a number of generics to control the size and location
of the different memory regions. The design supports only sizes that are powers
of 2, and locations that are aligned accordingly. This is purely for
simplicity.

The interpretation ("decoding") of the memory map takes place in lines 61-72 of
mem/mem.vhd. The postscript "cs" means "chip select". Note that there is no
rom\_wren, because we have removed to ability for the CPU to write to the ROM.

A default value of 0xFF has been given the colour memory. This means that
all characters have a default colour of white on black if the CPU doesn't write
to the colour memory.

## VGA access to the character and colour memory.
Both the CPU and the VGA module will be accessing the character and colour
memories independently of each other, and possibly simultaneously. This is no
problem, and the FPGA supports Dual Port memory. Essentially, a dual port
memory has two separate ports, with separate address and data bus, and possibly
even separate clock signal. For now, we'll leave everything in the same clock
domain, but to support dual port mode, we'll need a new memory interface. This
is implemented in the file mem/dmem.vhd. Note that from a VHDL perspective, the
only significant change is that there are now two address buses, one for
writing (connected to the CPU) and one for reading (connected to the VGA), i.e.
signals a\_addr\_i and b\_addr\_i.

## VGA Overlay
Since we now have two sources of VGA output, the character memory and the CPU
debug information, we'll implement the latter as an overlay. The file
vga/digits.vhd has been renamed to vga/overlay.vhd, and the bit 7 of the switch
(the "fast" mode) is simultaneously used to disable the CPU debug overlay when
in fast mode. This takes places in lines 139-142 of vga/vga.vhd.

## VGA character and colour display
A new file vga/chars.vhd is used for this. The implementation is somewhat
different, in that it uses a pipeline. This is because the FPGA must perform
several operations for each pixel, including reading the character from memory,
and this therefore takes several clock cycles.

The pipeline is described by the record t\_vga defined in lines 49-72 of
vga/chars.vhd.  The precise number of steps in the pipeline can be increased
and/or decreased, so the choices made here is mainly based on readability.

Each stage is delayed one clock cycle relative to the previous stage. The
length of the pipeline (i.e. number of stages) poses no problems, as long as
all signals are delayed the same amount.

### Stage 0 (lines 76-82)
In the initial stage the input signals pix\_x\_i and pix\_y\_i are copied
directly into stage 0 of the pipeline. There is no delay in this, and this
step serves only to improve readability.

### Stage 1 (lines 85-116)
In this stage we calculate - as before - the horizontal and vertical
synchronization signals. These signals will in the later stages be delayed so
they remain aligned with the generated colour signal.  The main part of this
step is to calculate the lookup address in the character and colour memories.
Since these memories are separate and distinct, we can perform lookups in both
memories simultaneously. The same address is used for both memories.

### Stage 2 (lines 119-159)
The actual lookup is done by connecting the address and data buses in lines
119-127.

Next, the font bitmap is determined by another lookup in lines 130-142. This
lookup is table-based and there is no clock cycle delay.

The remaining signals need to be copied over individually, in lines 145-159.

### Stage 3 (lines 162-195)
The font bitmap is 64 bits wide, and the particular bitnumber to use is
calculated in lines 177-180.

## Software support
Now that the firmware can display characters on the VGA output, this can be
used in software. A very simple version of printf() is implemented in the file
prog/printf.c. This version write only to the character memory, and not the
colour memory, so all text will be white on black for now. The memory map is
hardcoded in line 9. The location in character memory is calculated as 80\*y+x,
see line 26. This calculation corresponds to the equivalent calculation in
lines 113-114 of vga/chars.vhd.

