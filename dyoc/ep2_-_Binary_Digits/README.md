# Design Your Own Computer
# Episode 2 : "Binary Digits"

Welcome to the second episode of "Design Your Own Computer". In this
episode we focus on displaying 8 binary digits on the screen.

## Overall design of VGA module

It is useful to organize the source code in several small files rather than one
large file. Each small source file should have just a single functionality.
Therefore, the VGA part of the computer is now split into two:
* vga.vhd    : Generate pixel coordinates and synchronization signals.
* digits.vhd : Generate colour as a function of pixel coordinates.

In other words, the process to generate colours is removed from vga.vhd, and
instead we write a new file digits.vhd. We need to remember to update the
tcl-file and the Makefile.

In lines 19-25 of digits.vgd we start by copying some of the constants we need.
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
more visible in the source file.  In a later episode, we'll show how to load an
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

## Learnings:
Values assigned in a process are only stored at the end of the process.
Sequential calculations must be performed in parallel, e.g. by using separate
concurrent statements.
