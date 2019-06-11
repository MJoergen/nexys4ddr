# CPU offloader
# Episode 8 : "Math"

Welcome to this eigth episode of "CPU offloader", where we start
implementing mathematical functions in our design. The first
funcion we'll implement is the integer square root.

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
diretory math is added.
So far, this math module just instantiates the square root function.

## Sqrt module
The integer square root is calculated using the description in
[wikipedia](https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Binary_numeral_system_(base_2)).
Actually, the module calculates both the integer square root M = floor(sqrt(N))
and the remainder R = N-M\*M.  This implementation takes a fixed number of
clock cycles regardless of the input.

The control signals are fairly simple: On the input side the value N is
presented on the input bus val\_i, and the input signal start\_i is pulsed
once. Some time later the result will be present on the output busses res\_o
and diff\_o, and the output signal valid\_o will be held high. val\_i is only
read when start\_i is asserted. However res\_o and diff\_o will remain valid
until the next time start\_i is asserted.

There is an extra signal busy\_o which is asserted when a calculation is in
progress. It is not possible to interrupt a calculation, and asserting start\_i
will be ignored as long as busy\_o is asserted. 

## Testing in simulaion
Since there is a lot of processing involved in simulating the Ethernet
interface, it is much faster to have a separate test bench for the Math module.
So in the math directory just type make, and the math test bench in
tb\_math.vhd is run.

I've also made a separate test bench just for the sqrt module. Just uncomment
the line "#TB = tb\_sqrt" in the top of the Makefile.

## Testing in hardware
When the FPGA is programmed, it just waits for commands sent via UDP. So I've
modified the test program main.py to send specially formatted UDP frames to the
FPGA, and listen for corresponding replies.

It is important that the test program assumes the same data size as the FPGA
design. In the FPGA this is controlled in top.vhd in line 36. In the test program
it is in main.py in line 12.

