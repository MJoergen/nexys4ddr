# 2017-11-11 
Initial checkin. The purpose is to setup the project and get a display on the
VGA port.

The board is clocked by an external crystal of 100 MHz. The VGA port is
configured for a 1280x1024 display, and requires a clock of 108 MHz. This is
easily done by using the MMCM clock wizard.

# 2017-11-23
Reorganized the code, and added a small amount of graphics: Now it can display
a single binary digit, reflecting the input of the rightmost switch.

# 2017-11-25
Focused on the VGA display so far.

# 2017-12-02
I completely reworked the VGA part, making it into a proper 5-stage pipeline. The image
is much clearer, at the code is simpler too, I believe.

# 2017-12-03
I've implemented the ALU, and written a separate test bench for this module. I will
be writing test benches for most of the modules individually, in order to speed up
testing.
Added a multiplier unit in the ALU and instantiated the CPU. Currently, it doesn't meet 
timing, but with a WNS of arund -9 ns, it should be able to clock at 50 MHz. So I need
to set up a clock divider.

# 2017-12-03
I've disabled timing checks to and from the VGA module, because they are not relevant.
Now the design meets timing, but this doesn't prove much so far. I still need to implement
the entire CPU, in order for timing checks to become meaningfull.

# 2017-12-05
I've implemented the data path of the CPU, but it needs testing. I need to implement an
assembler at some point.

# 2017-12-06
Now the data path of the CPU seems to be working. An alpha-version of the assembler
has been made, and the instruction memory is initialized from a file (both in simulation
and in synthesis). Next is to show the entire register file on the VGA port.

# 2017-12-07
Now the entire register file is displayed on the VGA port. Next is to do more testing,
and then implement the rest of the CPU.
I'm looking at how to modify the CLANG compiler to generate beta-assembly code.
