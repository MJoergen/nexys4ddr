# Design Your Own Computer
# Episode 2 : "Binary Digits"

Welcome to the second episode of "Design Your Own Computer".
In this episode we will be accomplishing several tasks:
* Reorganize the code into separate subdirectories.
* Display 8 binary digits on the screen, based on the slide switches on the
  board.

The computer can now read the position of the slide switches
and display as binary digits on the screen.

## Reorganizing the code into separate subdirectories

The computer we're building will in the end contain four separate parts, each
belonging in a separate directory:
* vga  : VGA interface (GPU)
* main : Main part consisting of CPU and memory.
* kbd  : Keyboard interface
* eth  : Ethernet interface

Before we proceed it is useful to organize the source code in smaller units,
each with a single responsibility. So we will keep comp.vhd as the top level
block describing the entire computer, but move any logic into smaller parts. So
far we only have a VGA block, but eventually we'll have blocks for Main,
Keyboard, and Ethernet. We will leave the clock divider in comp.vhd for now.

The directory vga will contain three files:
* vga.vhd    : Wrapper connecting up the other two files.
* pix.vhd    : Generates the internal pixel counters.
* digits.vhd : Generates the colour and synchronization, as functions of the internal
               pixel counters.

We need to remember to update the tcl-file and the Makefile.

## Binary digits

The ability to display binary digits will be located in the file vga/digits.vhd.
We need to work on several parts:
* font  : How do we represent a font (bitmap) in VHDL ?
* logic : How do we display the bitmap correctly to VGA ?

### Font
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

### Logic
The way this display block works is that it takes the pixel coordinates (x,y)
as input and calculates the pixel colour as output. This calculation is broken
down into
a number of smaller steps:
* Which character row and coloumn (inside the 40x30 characters) are we
  currently at (determined from the input pixel coordinates). Lines 125-130 in digits.vhd.
* Which character to display at this position (based on the input digits). Lines 133-139.
* Fetch the bitmap associated with this particular character (from the font). Lines 142-147.
* Extract the particular pixel in this bitmap to display now. Lines 150-157.
* Choose colour based on this pixel. Lines 160-188.

Notice that the entire screen has a default background colour (defined in lines
168-169), and each text character has a (different) background colour (defined
in lines 178). The foreground colour of the character is defined in line 176.

## Input to VGA module
The value to display is taken from the slide switches on the FPGA board. We
therefore have to add the pin locations of these switches. This happens in
lines 18-25 in comp.xdc.  Additionally, we have to add the signals to the top
level entity declaration in line 16 of comp.vhd.

## Learnings:
Values assigned in a process are only stored at the end of the process.
Sequential calculations must be performed in parallel, e.g. by using separate
concurrent statements.

