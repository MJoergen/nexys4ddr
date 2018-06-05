# Design Your Own Computer
# Episode 23 : "Interrupt Controller"

Welcome to "Design Your Own Computer".  In this episode we'll add an
interrupt controller to the system.

## Why?
In the final system we'll be using interrupts for a number of things,
including:
* receiving keyboard data
* timer interrupt

The interrupt controller we'll build will support up to eight interrupt
sources, each of which can be individually masked (disabled). Futhermore, the
controller will allow the CPU to acknowledge receipt of each interrupt source.

The controller latches the incoming interrupt status, and clears it upon
reading from the interrupt status register.

## Memory Map
* 7FF7 : Interrupt mask. Each bit masks one of the eight interrupt sources.
* 7FFF : Interrupt status. Each bit shows the current status of the interrupt
  sources.
