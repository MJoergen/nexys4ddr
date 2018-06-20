# Design Your Own Computer
# Episode 25 : "Console I/O"
 
Welcome to "Design Your Own Computer".  In this episode we'll begin
implementing a rudimentary operating system. The first step is
to have a command line.

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
