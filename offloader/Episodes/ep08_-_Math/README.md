# CPU offloader
# Episode 8 : "Math"

Welcome to this eigth episode of "CPU offloader", where we start
implementing mathematical functions in our design. In this episode
we implement Multiplication and GCD.

## Cleanup
Before we proceed, I've decided to clean up the top module. First of all, I've
moved clock generation to a separate Clock and Reset module clk\_rst.vhd.  The
Ethernet reset generation from the file eth/eth.vhd is moved to the Clock and
Reset module too. This simplifies both the eth.vhd and top.vhd files. Remember
to update the top.xdc file.

## Clock domain crossing
It seems that the math functions should run at a faster clock rate than 50 MHz,
so I've added a new Math clock (currently at 100 MHz) to the Clock and Reset
module.  Furthermore, I've added Clock Domain Crossings in the top module
between the Ethernet clock and the Math clock. This Clock Domain Crossing is
implemented as a fifo in the file wide\_fifo.vhd and takes the wide data bus as
both input and output.

## Math module
In the top module, the inverter module is replaced by a math module, and a new
diretory math is added.  Some kind of data formatting is needed, and I've
decided to use the first two bytes as a command, and the following bytes as two
operands. This happens in lines 52-54 of math.vhd. The command decoding happens
in lines 56-57. Currently, two different operations are supported, GCD and
MULT. Both these operations are instantiated separately.

## Testing in simulaion
Since there is a lot of processing involved in simulating the Ethernet
interface, it is much faster to have a separate test bench for the Math module.
So in the math directory just type make, and the math test bench in
tb\_math.vhd is run.

## Testing in hardware
When the FPGA is programmed, it just waits for commands sent via UDP. So I've
modified the test program main.py to send specially formatted UDP frames to the
FPGA, and listen for corresponding replies.

