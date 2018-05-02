# Design Your Own Computer - Episode 3 : "Adding memory to the system"

Welcome to the third episode of "Design Your Own Computer". In this
episode we will be accomplishing several tasks:
* Adding memory to the computer
* Expanding the VGA output to show 24 bits (16 bits address and 8 bits data).
* Reorganize the code into separate subdirectories.
* Add a variable timer to slow down the speed.

The computer can now read contents from the memory and display to the VGA. The
speed of the timer can be controlled from the slide switches.

## Overall design of the computer

The computer we're building will in the end contain four separate parts, each
belonging in a separate directory:
* vga : VGA interface (GPU)
* mem : Memory (RAM and ROM)
* cpu : 6502 CPU
* kbd : Keyboard interface

The VGA part of the computer is now split into two:
* Generate pixel coordinates and synchronization signals.
* Generate colour as a function of pixel coordinates.

The new file added is mem/mem.vhd.
Furthermore, the original file vga.vhd is split into comp.vhd and vga/sync.vhd.
The top level file is now called comp.vhd

## Learnings:
Using GENERICS to parametrize an entity (similar to templates in C++).

