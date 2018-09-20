# Design Your Own Computer
# Episode 26 : "Ethernet Rx"
 
Welcome to "Design Your Own Computer".  In this episode we'll start
adding support for the Ethernet PHY. This first version will
enable us to receive data from the Ethernet port.

In this and the following episodes we'll build a web-server on the Nexys 4 DDR
board.

## Connecting up the Ethernet port

[Ethernet](https://en.wikipedia.org/wiki/Ethernet) is the protocol used to
physically connect computers together.  In the case of the Nexys 4 DDR board,
there is an Ethernet port on the board, and with a LAN cable the board can be
connected to a switch.

The Nexys 4 DDR boaard comes with a built-in Ethernet PHY device, see sheet 5
of the
[schematic](https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf).

The Ethernet PHY device is a small chip designed to handle the physical
encoding of the data onto the Ethernet port. For the Nexys 4 DDR board, they
have chosen the LAN8720A Ethernet PHY, see the
[documentation](http://ww1.microchip.com/downloads/en/DeviceDoc/8720a.pdf).

The functionality of this PHY chip includes:
* 100 MBit data transmission and reception full duplex.
* Autonegotiation of link speed (10/100) and duplex mode.
* Management interface to query link status and link speed.
* Loopback mode.

For now, we'll not support the management interface, instead relying on the
default values chosen at power-up.

## Interpreting the schematic
The particular PHY used on the board can operate in a number of different
modes, depending on how it is connected. Some on the pins on the PHY that are
normally used as outputs (from PHY to FPGA) are actually sensed (used as input)
on powerup, to configure default mode. This is controlled in hardware by using
either pull-up or pull-down resistors on these configuration pins.

So from the schematic we ascertain the following: 
* RXD0/MODE0    : External pull up
* RXD1/MODE1    : External pull up
* CRS\_DV/MODE2 : External pull up
* RXERR/PHYAD0  : External pull up
* MDIO          : External pull up
* LED2/NINTSEL  : External pull up
* NRST          : External pull up
* LED1/REGOFF   : Floating (internal pull down)

According to the datasheet this means:
* MODE     : All capable. Auto-negotiation enabled.
* PHYAD    : SMI address 1 (used for management only).
* REGOFF   : Internal 1.2 V regulator is enabled.
* NINTSEL  : nINT/REFCLKO is an active low interrupt output.
* REF\_CLK : Is sourced externally and must be driven
*            on the XTAL1/CLKIN pin.

Regarding the last line about REF\_CLK, this means the FPGA must supply a 50
Mhz clock output to the PHY.

## Adding top level ports
The first we need is to connect the PHY signals to our design. In comp.vhd we
add the ports to our entity declaration, and we must remember to add them to
the constrain file comp.xdc as well. The signal names and pin names are copied
from the schematic linked to above.

## Clocking
In most designs, the clocks are determined by the external interfaces. This
design is no exception.  So far we've had to interface to the VGA output at 25
MHz, Now we additionally have to interface to the Ethernet PHY, which runs at
50 Mhz. So our design will now contain two different "clock domains", i.e.
different areas of the design will be controlled by different clocks.

The Ethernet clock is generated in comp.vhd using the same clock divider as
for the VGA clock.

## Clock Domain Crossing
Considerable care must be taken whenever two clock domains need to exchange
information.  In this design, the CPU (running at 25 Mhz) must receive and
transmit data from the PHY (running at 50 MHz). The simplest way of
transferring data from one clock domain to another is to use a dual-clock fifo.
This is essentially a dual-port RAM with a write- and a read-pointer.

The Xilinx FPGA comes with built-in fifo primitives, which makes this solution
particularly simple to implement. A fifo is uni-directional, so we'll need two
fifo's, one for transmitting data to the PHY, and one for receiving data from
the PHY.

The file ethernet/fifo.vhd contains a wrapper for the Xilinx primitive. It is
usually a good idea to create wrappers around primitives, because it makes it
possible to choose more descriptive port names and improved error handling.
Note how the fifo has two different clocks, one for the write port and one
for the read port.

Note how the write sids has a wr\_afull\_o port. It is up to the user not to
write any more data to the fifo, when this signal is asserted. However, if it
does happen then the wr\_error\_o port will be asserted (and latched).
Similarly, the read side has a rd\_empty\_o port. Data should not be read from
the fifo when this signal is asserted. Again, an error signal is latched on
rd\_error\_o.

It is fairly straight-forward to design the system so that one doesn't read
from an empty fifo. However, avoiding writing to a full fifo requires an
understanding of the global system architecture. One must consider, whether the
receiver can pull data out of the fifo quickly enough, compared to how fast
data it pushed into the fifo. This also influences the choice of how big the
fifo should be,

## Overall design strategy
A number of blocks is needed in the design in order to facilitate reception
of Ethernet frames. They are:
* Interface to the Ethernet PHY - generating a byte stream with Start-Of-Frame
and End-Of-Frame markers.
* Header insertion - this strips away te CRC (and validates it), and inserts
two bytes in front of the packet with the total byte length.
* A fifo to provide for crossing from the Ethernet clock domain to the CPU
clock domain.
* A DMA to write the data to the memory.

## Data reception
The PHY chip connects to the FPGA using the [RMII
specification](https://en.wikipedia.org/wiki/Media-independent_interface#Reduced_media-independent_interface).
So the first task is to convert this interface to something that fits easily
into the fifo (needed for the clock domain crossing).

This is handled in ethernet/lan8720a/rmii\_rx.vhd.  This module takes care of:
* 2-bit to 8-bit expansion (user data output every fourth clock cycle @ 50 Mhz).
* CRC validation.
* Framing with SOF/EOF.
From this we see that data received from the PHY is at an equivalent clock rate
of 12.5 MHz (assuming one byte pr. clock cycle). That means that provided the CPU
can read from the fifo every second clock cycle, the fifo will not overflow.

## Code organization
A new folder 'ethernet' is added to contain everything related to the Ethernet
port. A sub-folder 'lan8720a' contains the direct interface to the PHY.



