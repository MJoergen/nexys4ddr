# Design Your Own Computer
# Episode 23 : "Interrupt Controller"

Welcome to "Design Your Own Computer".

In the previous episode we saw that out attempt to generate a nice
background pattern on the VGA output was not very successful. We are
clearly lacking the possibility of very precise synchronization with the
VGA output.

## Interrupt controller

The solution we use here is to implement interrupts. We will eventually
add support for several independent interrupts sources, but for now
we'll just have the VGA module generate interrupts, as well as having
a general timer interrupt.

We'll build an interrupt controller which will support up to eight interrupt
sources, each of which can be individually masked (disabled).  The controller
latches the incoming interrupts into an interrupt status register.  Whenever
the AND of this interrupt status latch and the corresponding interrupt mask register
is nonzero, then it asserts the interrupt pin irq\_i on the CPU.
The interrupt status latch is automatically cleared when the CPU reads from it.

## Memory Map
* 7FF7 : Interrupt mask. Each bit masks one of the eight interrupt sources.
* 7FFF : Interrupt status. Each bit shows the current status of the interrupt
  sources.  When reading from this memory location, all pending interrupts are
  cleared.

## Timer interrupt

