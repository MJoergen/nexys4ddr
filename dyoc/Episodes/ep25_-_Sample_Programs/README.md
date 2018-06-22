# Design Your Own Computer
# Episode 25 : "Sample Programs"
 
Welcome to "Design Your Own Computer".  In this episode we'll implement
some sample programs to demonstrate our new computer.
At the same time, we'll add some more library support.

## conio support
There are two different standards for I/O: stdio and conio.

Two of the main differences between these two I/O standards are:
* CR (\r) and LF (\n) have a different meaning. The first one moves the cursor
  to the beginning of the current line; the second one moves it straight down
  into the next line.
* conio doesn't scroll the screen when moving below the last line. In fact,
  allowing that to happen might spell disaster on several machines because, for
  performance reasons, there are no checks.

## Reusing previous FPGA image
Since there are no changes to the FPGA image (except for the ROM contents) it
makes sense to avoid having to resynthesize the FPGA image yet again.  Instead,
we make use of the tool 'data2mem' that can update an existing bit-file and
replace the BRAM contents.

## Update to makefile
Since we now have a separate conio library, the existing directory 'lib' has
been removed and replaced by two new directories 'conio' and 'runtime'. The
former has support for all the conio functions, while the latter has support
for the hardware vectors RESET and IRQ.

## Sample programs
A number of different demo programs are now available. To try them, you must
modify the first line of prog/Makefile. The following demo programs are
available:
* life : This is Conway's Game of Life. Currently, it runs approx 6 frames per second.
* maze2d : A two-dimensional maze.

