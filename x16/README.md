# Commander X16 #

This project aims at implementing the Commander X16 on the Digilent Nexys4DDR
board.

The Commander X16 board has the following features, all of which will be
implemented in the FPGA on the Digilent board.
* CPU (65C02 @ 8 MHz)
* GPU (VERA)
* 128 kB ROM (Banked)
* 2 MB RAM (Banked)
* VIA chips (Interfaces to keyboard)
* SD card (TBD)

The VERA chip contains additional 128 kB of video RAM.

The FPGA on the Digilent board is a Xilinx Artix-7 (XC7A100T), which contains
540 kB of Block RAM. So, this project will not support the full 2 MB of RAM
on the X16. It might be possible to use the DDR RAM avaiable on the board, but
this is TBD.

## Memory map
* 0x0000 - 0x9EFF : Low RAM
* 0x9F00 - 0x9FFF : I/O
* 0xA000 - 0xBFFF : Banked RAM (256 banks of 8 kB)
* 0xC000 - 0xFFFF : Banked ROM (8 banks of 16 kB)

### I/O memory map
* 0x9F00 - 0x9F1F : Reserved
* 0x9F20 - 0x9F3F : [VERA](fpga/vera/README.md)
* 0x9F40 - 0x9F5F : Reserved
* 0x9F60 - 0x9F6F : VIA1 (Selects ROM and RAM bank)
* 0x9F70 - 0x9F7F : VIA2 (Connected to PS/2 keyboard)
* 0x9F80 - 0x9F9F : RTC (not present on Digilent)
* 0x9FA0 - 0x9FFF : Reserved

## Banking

The ROM is banked as follows
* 0 : KERNAL
* 1 : KEYBD
* 2 : CBDOS
* 3 : GEOS
* 4 : BASIC
* 5-7 : Unused

To select the ROM bank, write to bits 2-0 of address 0x9F60.
To select the RAM bank, write to address 0x9F61.

## Log
I'm keeping a [log](log.md) of my progress, so I can keep track of all my
ideas.

## Links
* [Nexys4DDR board from Digilent](https://reference.digilentinc.com/reference/programmable-logic/nexys-4-ddr/start)
* [GitHub repository for the Commander X16 project](https://github.com/commanderx16)

