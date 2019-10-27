# VERA #

This directory contains an implementation of (a subset of) the VERA chip for
the Commander X16 computer.

This README contains the notes I've taken during the implementation. These
notes are gathered from the [Official VERA
Documentation](https://github.com/commanderx16/x16-docs/blob/master/VERA%20Programmer's%20Reference.md)
and from the source code for the X16 emulator.

## Memory map
The VERA chip has its own private 128 kB memory, with the following structure:
* 0x00000 - 0x1FFFF VRAM
* 0x20000 - 0xEFFFF Reserved
* 0xF0000 - 0xF0FFF Composer
* 0xF1000 - 0xF1FFF Palette
* 0xF2000 - 0xF2FFF Layer 1
* 0xF3000 - 0xF3FFF Layer 2
* 0xF4000 - 0xF4FFF Sprites
* 0xF5000 - 0xF5FFF SPR Data
* 0xF6000 - 0xF6FFF Reserved
* 0xF7000 - 0xF7FFF SPI
* 0xF8000 - 0xFFFFF Reserved

### Layer map
* 0x000         : Enabled and Mode
* 0x001         : Map width and height, Tile width and height
* 0x002 - 0x003 : Map Base
* 0x004 - 0x005 : Tile Base
* 0x006 - 0x007 : Horizontal scroll
* 0x008 - 0x009 : Vertical scroll

