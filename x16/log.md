# Progress Log

This file contains a brief description of my process with implementing the X16
on the Nexys4DDR board.

## 2019-10-26
Initial checkin, where the VGA port displays a simple checkerboard pattern in
640x480 resolution.  I'm planning on running the entire design using two
clocks: The VERA will run at the VGA clock of 25 MHz, and the rest of the
design will run at the CPU clock of 8 MHz.

Next step: In order to get the VERA to display more than a checkerboard, I need
to dive into the VERA documentation. My intention is to get the default
character mode to work. The challenging part is actually how to test this
incrementally, i.e without having to wait until everything is implemented. I
will probably just hard code some characters and fonts to begin with, but then
quickly move on to implement the interface to the 65C02, and then hardcode a
process that simulates the CPU writes to the VERA.

I will wait with implementing the CPU, as I already have a working 6502 from
the dyoc project, where I just need to modify it for the 65C02.

