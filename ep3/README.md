# Design Your Own Computer - Episode 3 : "Adding memory to the system"

Welcome to the third episode of "Design Your Own Computer". In this
episode we will be adding memory to the computer, and expanding the VGA output.
At the same time, we will reorganize the code into separate subdirectories.

## Overall design of the computer

The computer we're building will in the end contain four separate parts, each belonging in
a separate directory:
* vga : VGA interface (GPU)
* mem : Memory (RAM and ROM)
* cpu : 6502 CPU
* kbd : Keyboard interface

The VGA part of the computer is now split into two:
* Generate pixel coordinates and synchronization signals.
* Generate colour as a function of pixel coordinates.

The new file added is mem/mem.vhd.
Furthermore, the original file vga.vhd is split into comp.vhd and vga/sync.vhd.

## Learnings:

