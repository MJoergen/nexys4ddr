# VERA #

This directory contains an implementation of (a subset of) the VERA chip for
the Commander X16 computer.

This README contains the notes I've taken during the implementation. These
notes are gathered from the [Official VERA
Documentation](https://github.com/commanderx16/x16-docs/blob/master/VERA%20Programmer's%20Reference.md)
and from the source code for the X16 emulator.


## Memory map
The VERA chip has its own private 128 kB memory, with the following structure:
* 0x00000 - 0x1FFFF : Video RAM
* 0x20000 - 0xEFFFF : Reserved
* 0xF0000 - 0xFFFFF : Configuration registers, see below.


## Startup
Upon startup the KERNAL/BASIC performs the following sequence of writes to the VERA:
1. 0x0F800 - 0x0FFFF : Tile data.
2. 0xF3000 - 0xF3009 : Layer 2.  Values 01:06:00:00:00:3E:00:00:00:00
3. 0xF0000 - 0xF0008 : Composer. Values 01:80:80:0E:00:80:00:E0:28
4. 0x00000 - 0x03FFF : Clear screen. Values 20:61 repeated.
5. 0x00000 - 0x008FF : Display welcome screen.

In the first version of this implementation of VERA, all writes to the
configuration registers will be ignored, i.e.  only default values will be
used.


## Configuration registers
* 0xF0000 - 0xF001F : Display composer
* 0xF1000 - 0xF11FF : Palette
* 0xF2000 - 0xF200F : Layer 1
* 0xF3000 - 0xF300F : Layer 2
* 0xF4000 - 0xF400F : Sprite registers
* 0xF5000 - 0xF53FF : Sprite attributes
* 0xF6000 - 0xF6FFF : Reserved for audio
* 0xF7000 - 0xF7001 : SPI
* 0xF8000 - 0xFFFFF : Reserved

### Layer settings
* 0x000         : Enabled and Mode
* 0x001         : Map width and height, Tile width and height
* 0x002 - 0x003 : Map Base
* 0x004 - 0x005 : Tile Base
* 0x006 - 0x007 : Horizontal scroll
* 0x008 - 0x009 : Vertical scroll

## Startup layer settings
The default values are interpreted as follows:
* MODE = 0, which means 16 colour text mode
* MAPW = 2, which means 128 tiles wide
* MAPH = 1, which means 64 tiles high
* TILEW = TILEH = 0, which means each tile is 8x8
* MAPBASE = 0, which means the MAP area starts at 0x00000
* TILEBASE = 0x3E00, which means the TILE area starts at 0x0F800
* HSCROLL = VSCROLL = 0

## Startup composer settings
The default values are interpreted as follows:
* VGA output
* HSCALE = VSCALE = 0x80, which means 1 output pixel for every input pixel.
* HSTART = 0, HSTOP = 640
* VSTART = 0, VSTOP = 480

