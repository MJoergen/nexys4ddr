# Design Your Own Computer
# Episode 3 : "Adding memory to the system"

Welcome to the third episode of "Design Your Own Computer".
In this episode we will be accomplishing several tasks:
* Adding memory to the computer.
* Expanding the VGA output to show 24 bits (16 bits address and 8 bits data).
* Add a variable timer to slow down the speed.

The computer can now read contents from the memory and display to the VGA. The
speed of the timer can be controlled from the slide switches.

## What is memory?
Essentially, a memory is an array of words. In our 8-bit system, each memory
word is 8 bits, i.e. one byte. This means we can read or write one byte at a time.
The memory is declared in lines 39-56 of mem/mem.vhd, together with initial
contents at FPGA startup.  When using a memory, we therefore need to access a
random (arbitrary) element of this large array. This is also known as a
multiplexer.

Notice the definition of the memory block, given in lines 14-35 of mem/mem.vhd.
The memory interface consists of an address bus, and a data bus. Even though
the language (and the FPGA) supports bi-directional data ports, they are
error prone to use, and I therefore prefer to keep the read data and the write
data as two separate ports.

With two separate ports it is possible to read from and write to the memory
simultaneously. However, we will not be using that possibility in this design,
because the 6502 CPU does not support that.

It is nice to leave the memory size programmable. This is accomplished by the
use of *generics* in VHDL, see lines 15-19 in mem/mem.vhd. This is somewhat
comparable to templates in C++.

The memory is instantiated in lines 86-100 in comp.vhd, where the size of the
memory is chosen. For now we just choose a small size make debugging easier.

### What is inside an FPGA?
Let's talk a bit about what is physically inside an FPGA. Most of the silicon
area of an FPGA is used by combinatorial logic gates and by 1-bit memory cells
(also known as registers or flip/flops).  The synthesis tool decides to use
flip-flops when the design makes use a clocked processes. In other words, the
synthesis tool regards the clocked process as a *template* and based on this
template it *infers* one or more flip-flops.

Now, it is possible to build a RAM from only these basic building blocks, i.e.
flip-flops and combinatorial logic gates. However, large multiplexers use a lot
of logic gates, and there are better ways, because inside the FPGA some of the
silicon area is reserved for special purpose Block RAMs. The question is now
how to make use of these? Well, again, the synthesis tool recognizes certain
language templates.

This language template can be seen in lines 63-79 in mem/mem.vhd. Provided
the dimensions (sizes of address and data bus) meet certain requirements, the
synthesis tool will make use of the special purpose Block RAM instead of
ordinary general purpose logic gates and registers.

Note particularly that reading from memory must be inside a clocked process.
This means that the data read is available on the following clock cycle, i.e.
delayed one clock cycle. This will become important later on, when the CPU
needs to interface to the memory.

Notice the initialization of the memory contents in lines 42-56. In a later
episode we'll learn how to initialize the memory from a separate file.

## Expanding VGA output
This is surprisingly easy. The number of bits has been changed in line 9 of
vga/vga.vhd as well as line 15, lines 91-92, line 132, and line 165 of
vga/digits.vhd.  Furthermore, the position of the array on screen, given in
line 45 of vga/digits.vhd, has been moved slightly. And that is it!

It is somewhat cumbersome reading the output on the screen, because there
is no separation between the address bus and the data bus. This will be
fixed in a later episode.

## Timer
Currently, the entire design runs at the same clock frequency as the VGA, i.e.
25 MHz.  At this speed it is not possible to follow visually what is
happening. Therefore, we need to control the speed of the design. Not by
slowing down the clock, but instead by having an extra control signal that is
asserted only once every second, or so.

Since we later on will need a wait signal for the CPU, we introduce it here in
lines 57-69 of comp.vhd. This is basically a 25-bit counter, which wraps around
after 2^25 clock cycles, i.e. a little over one second. To control the speed,
the counter increment is controlled by the slide switches, so the increment can
be any value from 0 to 255. In this way, we can completely halt the execution
as well as speed up the execution to roughly 200 Hz.

## Learnings:
Using GENERICS to parametrize an entity (similar to templates in C++).

