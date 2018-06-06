# Design Your Own Computer
# Episode 24 : "Keyboard"
 
Welcome to "Design Your Own Computer".  In this episode we'll add the ability
to read key strokes from the keyboard, using the PS/2 interface.

## PS/2 interface
The PS/2 interface consist of a single clock line and a single data line. It is
the keyboard that generates both the data and the clock.  The data line must be
sampled at the falling edge of the clock line.

Data received on the PS/2 interface consists of 11 bits per byte: S01234567PT.
Here S is Start (always a '0'), P is parity (odd), and T is Stop (always a
'1'). The bits are sent over a serial link, where the keyboard generates both
clock and data.

In the FPGA, we wait for a falling edge on the PS/2 clock and shift the data
bit into a shift register.

After 11 bits, we can extract the byte from the shift register.  However, this
is not very robust, since if the FPGA should ever get out of synchronization,
it will forever remain out of synchronization. So we implement a simple state
machine that after the 11 bits checks the Start and Stop bits.  If they
are not correct, it will check after every bit, and wait for the correct values
of the Start and Stop bits.

## Memory map
The last keyboard event can be read from the address 7FFE. Additionally, an
interrupt is generated after each keyboard event. There is no buffering in the
FPGA, and therefore the keyboard interrupt must be serviced reasonably quickly.
Especially since the keyboard may generate several events back-to-back. Therefore,
keyboard handling is usually done in an interrupt service routine.

## Interrupt map
The keyboard is connected to bit 1 of the Interrupt Controller.

## Debug output
For now, we'll just display the current value of shift register on the VGA overlay.
