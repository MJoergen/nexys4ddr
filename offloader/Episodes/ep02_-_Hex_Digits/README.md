# CPU offloader
# Episode 2 : "Hexadecimal characters"

Welcome to this second episode of "CPU offloader", where we enable rendering of
hexadecimal characters on the VGA output.

The purpose of this episode is to be able to display a hexadecimal counter.
Later, we'll replace the counter with debug information about the network
processor.

## Code reorganization
Firstly, we begin to organize our source files. Since this project will grow
substantially, it is good advice to split the functionality into smaller
separate files.

All the VGA logic is moved to a separate directory vga, consisting of a number
of files:

* rom.vhd
* pix.vhd
* vga.vhd

The file rom.vhd is a wrapper for a generic ROM. The point is that the Vivado
tool allows for initializing the contents of the ROM directly from a text file.
Furthermore, the entire ROM gets synthesized into one or more BRAM's, without
any further logic.  This greatly saves on FPGA resources.

The file pix.vhd contains the pixel counters. The rest of the VGA logic is
placed in the file vga.vhd.

## VGA logic

The VGA logic is implemented in a 3-stage pipeline. This choice reflects very well
on the actual calculations the VGA module must perform. Let's break it down:

* From the pixel counters, calculate which character number we are currently
displaying.  Since the screen contains 80x60 characters, this will be a number
from 0 to 4799. This takes place in lines 123-128.

* From the character nunber, determine which part of the input signal hex\_i to
display.  I've chosen to start at the top left corner of the screen, and use
the first 64 characters of the top row to display the signal.  Since I want the
MSB to be in the top left corner, I need to invert the index.  All this takes
place in lines 130-134, and gives us the value of the 4-bit nibble.

* Now we must determine which ASCII character to use to represent this 4-bit value.
Here we just choose the characters '0' to '9' followed by 'A' to 'F'. This
takes place in lines 136-140.

* Finally, we must calculate the address into the font ROM. This address consists
of the ASCII character (8 bits) concatenated with the lowest three bits of the
pixel row.  Since each character is 8 rows high, this reads an entire line of
pixels for this particular character.

All the above calculations take place in stage 1 and the result is stored in
the register stage1.addr.

Note the use of variables within the VHDL process. Since this process is
synchronuous, the variables will be synthesized as separate regisers. However,
Vivado recognizes that the contents of the variables are not used later on, and
therefore the registers can be omitted. Instead, the variables get synthesized
to combinatorial logic alone.

After the above calculations, the second stage performs a lookup in the font
ROM.  This is done in lines 150-165. Note the process in lines 168-182. Here
the remaining registers of stage 1 are copied to stage 2. It has to be done
individually. Unfortunately, it won't work to just write "stage2 <= stage1",
because this will lead to multiple drivers of the signal stage2.bitmap.

The third (and last) stage selects the specific pixel from the font ROM based
on the three LSB's of the current column being displayed. This is again because
each character is 8 pixels wide. The characters are displayed as WHITE foreground on
DARK background. This all takes place in lines 186-215.


