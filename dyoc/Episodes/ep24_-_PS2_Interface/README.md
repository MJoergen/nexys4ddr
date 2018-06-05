# Design Your Own Computer
# Episode 24 : "PS/2 interface"
 
Welcome to "Design Your Own Computer".  In this episode we'll add support for the 
PS/2 interface.

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
machine that after the 11 bits it will check the Start and Stop bits.  If they
are not correct, it will check after every bit, and wait for the correct values
of the Start and Stop bits.

## Debug output
For now, we'll just display the current value of shift register on the VGA overlay.
