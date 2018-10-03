# Design Your Own Computer
# Episode 26 : "Ethernet PHY"
 
Welcome to "Design Your Own Computer".  In this episode we'll implement
the low-level connection to the Ethernet PHY.

In this and the following episodes we'll build a web-server on the Nexys 4 DDR
board.

## Connecting up the Ethernet port

[Ethernet](https://en.wikipedia.org/wiki/Ethernet) is the protocol used to
physically connect computers together.  In the case of the Nexys 4 DDR board,
there is an Ethernet port on the board, and with a LAN cable the board can be
connected to a switch.

The Nexys 4 DDR board comes with a built-in Ethernet PHY device, see sheet 5
of the
[schematic](https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf).

The Ethernet PHY device is a small chip designed to handle the physical
encoding of the data onto the Ethernet port. For the Nexys 4 DDR board, they
have chosen the LAN8720A Ethernet PHY.

According to the
[documentation](http://ww1.microchip.com/downloads/en/DeviceDoc/8720a.pdf), the
LAN8720A Ethernet PHY includes the following functionality:
* 100 MBit data transmission and reception full duplex.
* Autonegotiation of link speed (10/100) and duplex mode.
* Management interface to query link status and link speed.
* Loopback mode.

For now, we'll not support the management interface, instead relying on the
default values chosen at power-up.

## Interpreting the schematic
The LAN8720A PHY can operate in a number of different modes, depending on how
it is connected. Some on the pins on the PHY that are normally used as outputs
(i.e. from PHY to FPGA) are sensed (used as input) on power-up, to configure
the default mode. The default mode is selected in hardware by using either
pull-up or pull-down resistors on these configuration pins.

From the schematic we ascertain the following: 
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
* REF\_CLK : Is sourced externally and must be driven on the XTAL1/CLKIN pin.

Regarding the last line about REF\_CLK, this means the FPGA must supply a 50
Mhz clock output to the PHY.

## Adding top level ports
The first we need is to connect the PHY signals to our design. In comp.vhd
(lines 38-48) we add the ports to our entity declaration, and we must remember
to add them to the constraint file comp.xdc (lines 39-50) as well. The signal
names and pin names are copied from the schematic linked to above.

## Clocking
In most designs, the clocks are determined by the external interfaces. This
design is no exception.  So far we've had to interface to the VGA output at 25
MHz, Now we additionally have to interface to the Ethernet PHY, which runs at
50 Mhz. So our design will now contain two different "clock domains", i.e.
different areas of the design will be controlled by different clocks.

The Ethernet clock is generated in comp.vhd (line 137) using the same clock
divider as for the VGA clock. Additionally, all clock signals must be described
in the constraint file as well, i.e. in comp.xdc line 58.

## Interface to the Ethernet PHY (Data reception)
The PHY chip connects to the FPGA using the [RMII
specification](https://en.wikipedia.org/wiki/Media-independent_interface#Reduced_media-independent_interface).
So the first task is to convert the RMII interface to something that more easily
fits into the 8-bit oriented design of our computer.

This conversion is handled in ethernet/lan8720a/lan8720a.vhd.  This module take care of:
* 2-bit to 8-bit conversion (user data is output every fourth clock cycle @ 50 Mhz).
* CRC generation and validation.
* Framing with SOF/EOF.

The interface to this block is one byte pr. clock cycle, with SOF asserted on
the first byte of the MAC header and EOF asserted on the last byte.  When
transmitting, the user should not append a CRC, this is done automatically.  On
reception, the CRC remains, but there is no need to validate the CRC, as this
has already been done.  Two error bits are provided on reception (valid only at
EOF) that indicate either a receiver error or a CRC error.

## Testing

