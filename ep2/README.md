# Design Your Own Computer, Episode 2 : "Getting text on the screen"

Welcome to the second episode of "Design Your Own Computer". In this
episode we focus on getting actual text on the screen.

## Overall design of VGA module

The VGA part of the computer is now split into two:
* Generate pixel coordinates and synchronization signals.
* Generate colour as a function of pixel coordinates.

The new file added is digits.vhd

## Learnings:
Values assigned in a process are only stored at the end of the process. Sequential
calculations must be performed in parallel, e.g. by using separate concurrent
statements.

