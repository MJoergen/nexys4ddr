# Design Your Own Computer
# Episode 21 : "Reading From Display Memory"

Welcome to "Design Your Own Computer".  In this episode
we'll make it possible for the CPU to read from the character
and colour memories.

## Dual Port Memory
The FPGA has built-in support for dual port memory, but alas, it looks like we
need three ports. That is because we have already used two ports of each
of the character and colour memories (CPU write and VGA read). The CPU read
is supposed to happen on the falling clock edge, which requires a third
memory port. This is not possible, so we'll revert to having the CPU
read on the rising clock edge. This inserts a delay in each memory read
cycle from the character and colour memories.

To handle this extra delay, we'll re-use the existing mem\_wait signal in
comp.vhd. Until now, we've inserted arbitrary wait states to slow down

## CPU clock domain
We need the CPU to be able to read and write to and from the character
memory as well.
The Block RAM resources in the FPGA do indeed support Dual Port Mode, i.e.
with one write port (the CPU) and two read ports (the CPU and the VGA module).
However, since the CPU expects memory to be asynchronous, we have until now
made the CPU read on the *falling* clock edge. This won't work now, because
the FPGA considers this a different clock domain.

With the above description we habe a total of three clock domains: CPU rising
edge, CPU falling edge, and VGA rising edge. There are two approaches to
getting around this. One is to force the CPU and VGA to use the same clock ( as
they indeed to at the moment), thus equating the CPU rising edge and the VGA
rising edge.  The other approach is to tell the CPU to use synchronuous reads
when reading from the character and colour memmories. This latter is the
preferred approach as it is more flexible, allowing the CPU and the VGA modules
to have different clock speeds.  Furthermore, the support for synchronuous
reads is already implemented in the wait signal.

