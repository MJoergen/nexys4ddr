# Design Your Own Computer
# Episode 20 : "Text Display"

Welcome to the twentieth episode of "Design Your Own Computer".

We now want to expand on the VGA support. We'll enable the display of 80x60
coloured characters.

To do this we need to do the following:
* Determine a colour scheme.
* Implement coloured character display in the VGA module.
* Modify memory map by adding the character and color memories.
* Allow the VGA module access to these memory regions.
* Software support.

Furthermore, we wish to retain the ability to display the CPU debug on the VGA
output.


## Colour scheme
This may sound trivial, why not just use one byte per character to determine
the colour of this particular character? Well, that is indeed a possible
approach, but it does mean that all characters on the screen have the same
*background* colour.

Another approach is to assign *two* bytes of colour to each character, thus
allowing full control of both foreground and background colour of each
character. This is also possible but does require twice as much memory for the
colour information.

Instead, I've chosen to use a colour index (or palette). So the colour
information of each character consists of two 4-bit colour indeces (foreground
and background).  Each 4-bit colour index is then mapped to an 8-bit colour
using a global colour palette.  The only real benefit of this more complicated
implementation is to save of the amount of memory needed for the colour
information.

So to summarize, each byte of colour memory is divided into two 4-bit colour
indices, where the MSB is mapped to the background colour, and the LSB is
mapped to the foreground colour.

The colour palette will consist of sixteen different colours, and I've just
chosen a selection of various colours, where the value 0 maps to 0x00 (black),
and the value 15 maps to 0xFF (white).

The default colour index in the colour memory is 0x0F, which therefore
corresponds to white text on black background.


## VGA character and colour display
A new file vga/chars.vhd is used to implement the display of coloured
characters. The implementation is somewhat different from e.g. vga/overlay.vhd,
in that it uses a pipeline. This is because the operations needed to determine
the pixel colour takes several clock cycles.

The pipeline is described by the record t\_vga defined in lines 51-74 of
vga/chars.vhd.  The precise number of steps in the pipeline can be increased
and/or decreased, so the choices made here are somewhat arbitrary and mainly
based on readability.

Each stage will be delayed one clock cycle relative to the previous stage. The
total length of the pipeline (i.e. number of stages) poses no problems, as long
as all signals are delayed the same amount. This is easily achieved by having
all signals in the same record t\_vga.

### Stage 0 (lines 78-84)
In the initial stage the input signals pix\_x\_i and pix\_y\_i are copied
directly into stage 0 of the pipeline. There is no delay in this, and this
step serves only to improve readability.

### Stage 1 (lines 87-119)
In this stage we calculate - as before - the horizontal and vertical
synchronization signals. These signals will in the later stages be delayed so
they remain aligned with the generated colour signal.  The main part of this
step are lines 112-117, where we calculate the lookup address in the character
and colour memories.  Since these memories are separate and distinct, we can
perform lookups in both memories simultaneously. The same address is used for
both memories.

The lookup address is calculated by first determining the character row and
column. This is done by dividing the pixel counters by eight, i.e. removing the
lower three bits, since the font size is 8x8 pixels. The offset address in
memory is then calculated as 80\*y+x, where 80 is the number of characters in
the horizontal direction.  In the source code I've used the symbol H\_CHARS for
readability. This formula is a convenient choice, where offset zero corresponds
to the top left corner.  Other choices are possible too, and the main
requirement is that there is a unique 1-1 correspondence between the character
position on the screen, and the memory address offset.

### Stage 2 (lines 122-162)
The actual lookup in the character and colour memories is done by connecting
the address and data buses in lines 122-130.  Note that the character and
colour memories are synchronuous, which means there is a one clock cycle delay
from address to data. This is the reason why the address is in stage 1, whereas
the data is in stage 2.

Next, the font bitmap is determined by another lookup in lines 133-145. This
lookup is table-based i.e. combinatorial and there is no clock cycle delay.
Therefore, both address and data belong to stage 2. The font memory is
combinatorial, because it has no clock input.

The remaining signals need to be copied over individually, in lines 148-162.

### Stage 3 (lines 165-200)
The font bitmap is 64 bits wide, and the particular bitnumber to use is
calculated in lines 181-184. The main point is we need to take the pixel
coordinates modulo 8 (the font size in pixels). Since 8 is a power of two, this
modulo operation consists simply of taking the lower three bits of the pixel
coordinates. The font data is - as before - arranged as eight rows of eight
pixels, with bit number 0 in the lower left corner. This is the reason why we
in line 182 have to subtract the y-coordinate from 7.

The colour index from the colour memory is split into two halves, foreground
and background, in lines 186-191. Finally, in line 192 the colour index
is used to extract the pixel colour from the colour palette.


## Memory map
The screen resolution is 640x480 pixels and since our font is 8x8 pixels this
gives a screen size of 80x60 characters, i.e. 4800 bytes (or 0x12C0 in
hexadecimal).  For simplicity we'll allocate 8 Kbytes for the character screen,
i.e. 0x2000 bytes.  We'll add colours to each character as well, so that's
another 8 Kbytes.

The CPU can access the character memory and the colour memory by writing to the
following address ranges:
* 0x8000 - 0x92BF : Character memory
* 0xA000 - 0xB2BF : Colour memory

Addresses within 0x8000 - 0xBFFF but outside the above ranges are not used.

The current design will only allow the CPU to write to but not read from these
memory ranges.  Allowing the CPU to read from these memory ranges will require
a rather large number of additional changes, so that is deferred to the next
episode.

By now we have four different active memory ranges (ROM, RAM, CHAR, and COL),
and it is practical to make the design slightly more generic. Therefore, in
mem/mem.vhd we've added a number of generics to control the size and location
of the different memory regions. The design supports only sizes that are powers
of 2, and locations that are aligned accordingly. This is purely for
simplicity.

The interpretation (i.e. decoding) of the memory map takes place in lines 61-72
of mem/mem.vhd. The postscript "cs" means "chip select". Note that there is no
rom\_wren, because we have removed to ability for the CPU to write to the ROM.
The definition of the memory map is moved to the file comp.vhd in lines
139-147, and an equivalent C-style copy is maintained in file prog/memorymap.h.


## VGA access to the character and colour memory.
Both the CPU and the VGA module will be accessing the character memory
independently of each other, and possibly simultaneously. The same is true for
the colour memory.

This is no problem since the FPGA supports Dual Port memory.  Essentially, a
dual port memory has two separate ports, with separate address and data buses,
and possibly even separate clock signals. For now, we'll leave everything in
the same clock domain, but in order to support dual port mode, we'll need a new
memory interface. This is implemented in the file mem/dmem.vhd. Note that from
a VHDL perspective, the only significant change (compared to a regular RAM,
i.e. mem/ram.vhd) is that there are now two address buses, one for writing
(connected to the CPU) and one for reading (connected to the VGA), i.e.
signals a\_addr\_i and b\_addr\_i.

The character and colour memories are instantiated in lines 91-125 of mem/mem.vhd.
Note that a default value of 0x0F has been given in line 116. This means that
all characters have a default colour of white on black if the CPU doesn't write
to the colour memory.


## VGA Overlay
Since we now have two sources of VGA output, the character memory and the CPU
debug information, we'll implement the latter as an overlay. The file
vga/digits.vhd has been renamed to vga/overlay.vhd, and the bit 7 of the switch
(the "fast" mode) is simultaneously used to disable the CPU debug overlay when
in fast mode, see lines 107-111 of comp.vhd.  The actual overlay takes places
in lines 141-144 of vga/vga.vhd.


## Software support
Now that the firmware can display characters on the VGA output, this can be
used in software. A very simple version of printf() is implemented in the file
lib/printf.c. This version writes only to the character memory, and not the
colour memory, so all text will be white on black for now.  The location in
character memory is calculated as 80\*y+x, see e.g. line 26, where
I've used the constant H\_CHARS defined in prog/printf.h. This calculation
corresponds to the equivalent calculation in lines 116-117 of vga/chars.vhd.

Furthermore, a new file prog/memorymap.h has been added. This is to avoid having
the software hardcode addresses etc. in the source code.

The C source code has been reorganized, and the runtime library has been
moved to a separate directory lib. The source file for the main function
has been renamed from rom.c to main.c.

The test program prints out 70 numbered lines of text. In the current implementation,
the text will wrap around, and the last lines will appear at the top of the screen.

