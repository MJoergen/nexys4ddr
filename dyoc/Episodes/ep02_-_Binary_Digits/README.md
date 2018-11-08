# Design Your Own Computer
# Episode 2 : "Binary Digits"

Welcome to the second episode of "Design Your Own Computer".
In this episode we will be accomplishing several tasks:
* Display 8 binary digits on the screen.
* Reorganize the code into separate subdirectories.

The computer can now read the position of the slide switches
and display as binary digits on the screen.

## Overall design of the computer

The computer we're building will in the end contain four separate parts, each
belonging in a separate directory:
* vga : VGA interface (GPU)
* mem : Memory (RAM and ROM)
* cpu : 6502 CPU
* kbd : Keyboard interface
* eth : Ethernet interface

Before we proceed it is useful to organize the source code in smaller units,
each with a single responsibility. So we will keep comp.vhd as the top level
block describing the entire computer, but move any logic into smaller parts. So
far we only have a VGA block, but eventually we'll have blocks for Memory, CPU,
Keyboard, and Ethernet. We will leave the clock divider in comp.vhd for now.

The directory vga will contain three files:
* vga.vhd    : Wrapper connecting up the other two files.
* pix.vhd    : Generates the internal pixel counters.
* digits.vhd : Generates the colour and synchronization, as functions of the internal
               pixel counters.

We need to remember to update the tcl-file and the Makefile.

## Binary digits

The new functionality will now be located in the file vga/digits.vhd.

Since powers of two are the easiest numbers to work with, and since this
is an 8-bit computer, we'll be using an 8x8 font. I like to use a larger font
so each symbol on the screen will be scaled by a factor of 2, thus taking up
up 16x16 pixels of screen space. This makes the total number of 
characters on the screen to be 40x30 characters, because 640/16 = 40 horizontal
and 480/16 = 30 vertical.

For now, only two symbols will be defined ('0' and '1'). This is done in lines
53-80 in digits.vhd. The font is copied from
[another project](https://github.com/dhepper/font8x8/blob/master/font8x8_basic.h).
I've converted the font data to binary in order to make the display of the font
more visible in the source file.  In a later episode, we'll see how to load an
entire font from a separate file.

The position on screen of the 8 binary digits is defined in lines 49-51 of
digits.vhd. The values chosen correspond to roughly the middle of the screen.

The way this display block works is that it takes the pixel coordinates (x,y)
as input and calculates the pixel colour as output. This calculation is broken
down into
a number of smaller steps:
* Which character row and coloumn (inside the 40x30 characters) are we
  currently at (determined from the input pixel coordinates). Lines 125-130 in digits.vhd.
* Which character to display at this position (based on the input digits). Lines 132-138.
* Fetch the bitmap associated with this particular character (from the font). Lines 140-145.
* Extract the particular pixel in this bitmap to display now. Lines 147-154.
* Choose colour based on this pixel. Lines 156-184.

Notice that the entire screen has a default background colour (defined in lines
164-165), and each text character has a (different) background colour (defined
in lines 174). The foreground colour of the character is defined in line 172.

## Input to VGA module
The value to display is taken from the slide switches on the FPGA board. We
therefore have to add the pin locations of these switches. This happens in
lines 18-25 in comp.xdc.  Additionally, we have to add the signals to the top
level entity declaration in line 16 of comp.vhd.

## Learnings:
Values assigned in a process are only stored at the end of the process.
Sequential calculations must be performed in parallel, e.g. by using separate
concurrent statements.

