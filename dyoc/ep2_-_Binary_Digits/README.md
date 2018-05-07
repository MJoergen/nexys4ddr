# Design Your Own Computer
# Episode 2 : "Binary Digits"

Welcome to the second episode of "Design Your Own Computer". In this
episode we focus on displaying 8 binary digits on the screen.

## Overall design

Before we proceed it is useful to organize the source code in smaller units,
each with a single responsibility. So we will keep comp.vhd as the top level
block describing the entire computer, but move any logic into smaller parts. So
far we only have a VGA block, but eventually we'll have blocks for CPU, Memory,
and Keyboard.

The directory vga/ will contain three files:
* sync.vhd   : Generates the internal pixel counters
* digits.vhd : Generates the colour and synchronization, as function of the internal
pixel counters.
* vga.vhd    : Ties together the two files above.

We need to remember to update the tcl-file and the Makefile.

## Binary digits

The new functionality will now be located in the file vga/digits.vhd.

In lines 19-25 we start by copying some of the constants we need.
This unfortunately violates the very good principle DRY (Don't Repeat
Yourself). There are ways to avoid this in VHDL, but for now we'll just accept
this small amount of duplicate code. But it does mean, that if you decide to
change the screen resolution, you have to modify the constants in both the
vga.vhd and the digits.vhd files.

Since powers of two are the easiest numbers to work with, and since this
is an 8-bit computer, we'll be using an 8x8 font. I like to use a larger font
so each symbol on the screen will be scaled by a factor of 2, thus taking up
up 16x16 pixels of screen space. This makes the total number of 
characters on the screen to be 40x30 characters, because 640/16 = 40 horizontal
and 480/16 = 30 vertical.

For now, only two symbols will be defined ('0' and '1'). This is done in lines
33-60 in digits.vhd. The font is copied from
[another project](https://github.com/dhepper/font8x8/blob/master/font8x8_basic.h).
I've converted the font data to binary in order to make the display of the font
more visible in the source file.  In a later episode, we'll see how to load an
entire font from a separate file.

The position on screen of the 8 binary digits is defined in lines 29-31 of
digits.vhd. The values chosen correspond to roughly the middle of the screen.

The way this display block works is that it takes the pixel coordinates (x,y)
as input and calculates the pixel colour as output. This calculation is broken
down into
a number of smaller steps:
* Which character row and coloumn (inside the 40x30 characters) are we
  currently at (determined from the input pixel coordinates). Lines 96-101 in digits.vhd.
* Which character to display at this position (based on the input digits). Lines 103-109.
* Fetch the bitmap associated with this particular character (from the font). Lines 111-116.
* Extract the particular pixel in this bitmap to display now. Lines 118-125.
* Choose colour based on this pixel. Lines 128-156.

Notice that the entire screen has a default background colour (defined in lines
136-137), and each text character has a (different) background colour (defined
in lines 146). The foreground colour of the character is defined in line 144.

## Input to VGA module
The value to display is taken from the slide switches on the FPGA board. We
therefore have to add the pin locations of these switches. This happens in
lines 18-25 in vga.xdc.  Additionally, we have to add the signals to the top
level entity declaration in line 9 of vga.vhd.

## Timing
Some words on the timing of the synchronization and colour signals. It is
important that the timing specification in the VESA standard is followed. In
our implementation both the synchronization signals and the colour signals are
derived from (i.e. functions of) the pixel counters. So in lines 95-119 of
vga.vhd the synchronization signals are driven in a clocked process. This means
that the synchronization signals are delayed one clock cycle compared to the
pixel counters. However, the same applies to the colour signals driven in lines
128-156 of digits.vhd. Here too, the signals are delayed one clock cycle.
All-in-all, since both the synchronization signals and the colour signals are
delayed the same amount, they will be mutually consistent.

Later, we'll add more clock cycle delays in the colour generation, and we must
therefore ensure the same amount of delay in the synchronization signals.

I highly encourage you to play around with the delay of either the
synchronization signals or the colour signals to see what happens.

## Learnings:
Values assigned in a process are only stored at the end of the process.
Sequential calculations must be performed in parallel, e.g. by using separate
concurrent statements.

