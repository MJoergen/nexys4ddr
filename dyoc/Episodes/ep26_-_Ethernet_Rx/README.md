# Design Your Own Computer
# Episode 26 : "Ethernet Rx"
 
Welcome to "Design Your Own Computer".  In this episode we'll start
adding support for the Ethernet PHY. This first version will
enable us to receive data from the Ethernet port.

## Ethernet
Ethernet is the protocol used to physically connect computers together. In the
case of the Nexys 4 DDR board, there is an Ethernet port on the board, and with
a LAN cable the board can be connected to a switch.

In this and the following episodes we'll build a web-server on the Nexys 4 DDR
board.

## Connecting up the Ethernet port
The Nexys 4 DDR boaard comes with a built-in Ethernet PHY device, see sheet 5
of the schematic here:
https://reference.digilentinc.com/_media/reference/programmable-logic/nexys-4-ddr/nexys-4-ddr_sch.pdf

The Ethernet PHY device is a small chip designed to handle the physical
encoding of the data onto the Ethernet port. For the Nexys 4 DDR board, they
have chosen the LAN8720A Ethernet PHY, see the documentation here:
http://ww1.microchip.com/downloads/en/DeviceDoc/8720a.pdf

The functionality of the PHY chip includes:
* 100 MBit data transmissin full duplex (default).
* Autonegotiation of link speed (10/100) and duplex mode.
* Management interface to query link status and link speed.
* Loopback mode.






The Ethernet protocol is described in https://en.wikipedia.org/wiki/Ethernet

