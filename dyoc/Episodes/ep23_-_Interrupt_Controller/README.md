# Design Your Own Computer
# Episode 23 : "Interrupt Controller"

Welcome to "Design Your Own Computer".

In the previous episode we saw that our attempt to generate a nice background
pattern on the VGA output while simultaneously doing other computations was
not very successful. We are clearly lacking the possibility of very precise
synchronization with the VGA output.

To achieve this synchronization we'll make a number of modifications
to the FPGA and to the software, all regarding interrupts.

## Changes to the FPGA

Inside the FPGA we'll add an interrupt controller. Additionally, we'll add
a small counter to generate timer interrupts. There will be changes to the
VGA module and the memory map IO module too.

### Interrupt Controller

We will use interrupts to achieve the required synchronization. Eventually, we
will add support for several independent interrupts sources, but for now we'll
just have two interrupts: A general timer interrupt, and interrupt from the VGA
module.

We'll build an interrupt controller in the file fpga/ic.vhd that will support
up to eight interrupt sources, each of which can be individually masked
(disabled).  The interrupt controller latches the incoming interrupts into an
interrupt status register.  Whenever the AND of this interrupt status latch and
the corresponding interrupt mask register is nonzero, the controller will
assert the interrupt pin irq\_i on the CPU.  The interrupt status latch is
automatically cleared when the CPU reads from it.

The interrupt controller is implemented in the new file fpga/ic.vhd and is
instantiated in lines 213-226 of fpga/comp.vhd. Furthermore, the interrupt
sources are connected in lines 296-302.

### Memory Mapped IO
It is necessary that the CPU acknowledges an interrupt so the Interrupt
Controller can deassert the irq\_i pin on the CPU. One simple way is to have
the interrupt status latch automatically cleared, when the CPU reads it.  It is
somewhat counter intuitive that a read operation has side-effects, and this is
therefore generally considered a bad praxis. Nevertheless, I've chosen
simplicity of implementation is this siuation.

To achieve the required side effect we must add a new signal b\_memio\_rden\_o
to the file mem/mem.vhd. I've chosen a rather general implementation where
each bit in the signal corresponds to one of the read-only bytes of the Memory
Mapped IO. The signal is generated in lines 94-99 of mem/mem.vhd.

### Timer counter
I've chosen to generate timer interrupts at 100 times per second. Too many
interrupts will slow down the program execution, while too few interrupts will
give a poorer timer resolution. One hundred interrupts per second seems like
a reasonable compromise.

Since the FPGA is running at 25 MHz, we need to generate an interrupt every 250
thousand clock cycles. This is achieved by having a counter that wraps around
upon reaching the value 250000. This value can be represented in 18 bits,
since 2^18 = 262144.

The counter is declared in lines 87-93 of fpga/comp.vhd, and the timer interrupt
is generated in lines 253-268.

There will be no support for reading the 18-bit timer interrupt counter.

### VGA module
We would like the VGA module to be a source for generating interrupts based on the
current pixel line being displayed at the moment. Therefore, I've chosen to
allow the CPU to control on which line to generate interrupt. This is done by
adding two more bytes to the Memory Mapped IO. The interrupt is generated at the
end of the requested line, and is done in lines 170-172 of vga/vga.vhd.

## Changes to the software

A substantial number of changes to the software is needed to support the new
interrupts, including
* Memory Map
* Startup code
* Interrupt handling
* Library support

### Memory Map

The file include/memorymap.h has been updated by adding the following registers:
* 7FD0 : VGA\_PIX\_Y\_INT. This 16-bit number contains the pixel line number for
  generating interrupt.
* 7FDF : IRQ\_MASK. Each bit masks one of the eight interrupt sources.
* 7FFF : IRQ\_STATUS. Each bit shows the current status of the interrupt
  sources.  When reading from this memory location, all pending interrupts are
  cleared.

Additionally two constants IRQ\_TIMER\_NUM and IRQ\_VGA\_NUM, have been
defined. These values must match the assignment of interrupt sources in
fpga/comp.vhd lines 296-302.

### Startup code
The (empty) definitions of nmi\_int and irq\_int have been moved from
lib/crt0.s to a new file lib/irq.s, more on that later.

In lines 56-62 of lib/crt0.s, the timer interrupt (bit 0) is enabled and the
CPU interrupt mask register is cleared, thus enabling timer interrupts. Note,
this must be done as the very last step before calling main(), because the
interrupt service routine in lib/irq.s expects the DATA segment to be
initialized.

### Interrupt handling
The new file lib/irq.s provides a generic interrupt handler, fetching the
specific interrupt handler from a jump table in lines 26-34. This makes it
possible for a running program to change the interrupt handler. Note that the
default interrupt handlers are disabled, except for the timer interrupt.  The
allocation of interrupt numbers must match the bit ordering as given in
fpga/comp.vhd.

It is imperative that the interrupt service routines are very fast, and that
they do not use any of the existing C routines. This is because the C runtime
is not re-entrant. Therefore, the interrupt service routines are best
handwritten entirely in assembly.  Additionally, they MUST preserve the
contents of the 'A' and 'Y' registers.

The timer interrupt service routine in lib/timer\_isr.s maintains a two-byte
counter that is updated every 0.01 seconds. It wraps around every approx.
ten minutes.

### Library support
To install a new interrupt service routine, the function sys\_set\_vga\_irq()
in lib/sys\_irq.c should be used.

To read the current value of the timer, just use the clock() function from the
standard library. This is implemented in lib/clock.s.

### Test program
The whole point of introducing interrupts was to be able to precisely control
the background colour of the VGA output. This is achieved by enabling VGA
interrupt in lines 70-71 of src/main.c.

The VGA interrupt file src/vga\_isr.s first copies the current pixel line
number to the background palette colour. The counter is then incremented and
stored as the next interrupt line.  This way, an interrupt is generated after
each VGA line, which happens every 800 clock cycles (the horizontal pixel
count).

In order to use the clock() function, it is necessary to define the
constant CLOCKS\_PER\_SEC, because this constant is platform dependent.
The option I've chosen is to define the symbol \_\_ATMOS\_\_ in line 11 of
src/main.c.

