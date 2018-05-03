# Design Your Own Computer - Episode 2 : "Getting text on the screen"

Welcome to the second episode of "Design Your Own Computer". In this
episode we focus on displaying 8 binary digits on the screen.

## Overall design of VGA module

The VGA part of the computer is now split into two:
* Generate pixel coordinates and synchronization signals.
* Generate colour as a function of pixel coordinates.

In other words, the process to generate colours is removed from vga.vhd, and
instead we write a new file digits.vhd. We need to remember to update the
tcl-file and the Makefile.

In lines 19-25 of digits.vgd we start by copying some of the constants we need.
This violates the very good principle DRY (Don't Repeat Yourself). There are
ways to avoid this in VHDL, but for now we'll just accept this small amount of
duplicate code. But it does mean, that if you decide to change the screen
resolution, you have to modify the constants in both the vga.vhd and the
digits.vhd files.

Since powers of two are the easiest numbers to work with, and since this
is an 8-bit computer, we'll be using an 8x8 font. I like to use a larger font
so each symbol in the font will be scaled by a factor of 2, so it in total
takes up 16x16 pixels of screen space. This makes the total number of 
characters on the screen 640/16 = 40 horizontal and 480/16 = 30 vertical.
I.e. this block can display 40x30 characters.

For now, only two symbols will be defined ('0' and '1'). This is done in lines
33-60 in digits.vhd. In a later episode, we'll show how to load a font from a
separate file.

The position of the 8 binary digits is defined in lines 29-31 of digits.vhd.

The way this display block works is that it takes the pixel coordinates (x,y)
as input and calculates the pixel colour as output. This calculation is broken
down into
a number of smaller steps:
* Which character row and coloumn (inside the 40x30 characters) are we
  currently at (determined from the input pixel coordinates).
* Which character to display at this position (based on the input digits).
* Fetch the bitmap associated with this particular character (from the font).
* Extract the particular pixel in this bitmap to display now.
* Choose colour based on this pixel.


## Learnings:
Values assigned in a process are only stored at the end of the process.
Sequential calculations must be performed in parallel, e.g. by using separate
concurrent statements.

