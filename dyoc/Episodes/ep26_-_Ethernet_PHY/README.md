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

The Ethernet clock is generated in comp.vhd (line 131) using the same clock
divider as for the VGA clock. Additionally, all clock signals must be described
in the constraint file as well, i.e. in comp.xdc line 58.

## Clock domain crossing
In this first version there will be no communication between the two clock
domains described. However, in the next episode we'll be transferring data
(ethernet frames) between the VGA and ETH clock domains, and we'll then have to
deal with issues related to clock domain crossing. In this episode, we can ignore
all these issues.

## Interface to the Ethernet PHY
The PHY chip connects to the FPGA using the [RMII
specification](https://en.wikipedia.org/wiki/Media-independent_interface#Reduced_media-independent_interface).
So the first task is to convert the RMII interface to something that more easily
fits into the 8-bit oriented design of our computer.

Eventually, we want the computer to automatically copy the received ethernet
frames directly to memory, and similarly automatically read ethernet frames for
transmission directly from memory. This is called Direct Memory Access (DMA).

Therefore, we will need a convenient interface to and from the Ethernet PHY.
The interface we would like should have the following features:
* One byte is transferred at a time (i.e. one byte pr. clock cycle).
* There should be a 'valid' signal allowing for clock cycles without any byte
  transfer.
* There should be a 'eof' signal to indicate the last byte of an Ethernet frame
  ("End Of Frame").
* CRC calculation and validation should be done automatically.

To convert from this interface to the RMII interface (and back), I've written
the module ethernet/lan8720a/lan8720a.vhd, which takes care of:
* 2-bit (RMII) to 8-bit (byte) conversion.
* CRC generation/appending and validation/stripping.
* Framing with VALID and EOF.

Therefore, we require the following signals when receiving from the Ethernet
PHY:
* rx\_valid\_o : 1 bit.
* rx\_data\_o  : 8 bits.
* rx\_eof\_o   : 1 bit.
* rx\_error\_o : 2 bits (one bit for receive error from the PHY, one bit for
  CRC error).

The two error bits are valid only on the last byte of the freame, i.e. when
both EOF and VALID are asserted.

When transmitting Ethernet frames to the PHY, the following interface will be used:
* tx\_empty\_i   : in    std\_logic;
* tx\_data\_i    : in    std\_logic\_vector(7 downto 0);
* tx\_eof\_i     : in    std\_logic;
* tx\_rden\_o    : out   std\_logic;
* tx\_err\_o     : out   std\_logic;

The 'empty' signal is deasserted, when the application has data to send. The
'rden' ("Read Enable") signal is asserted when the current values in 'data' and
'eof' have been consumed.

Note that during transmission it is not allowed to pause in the middle of a
frame, i.e. to assert the 'empty' signal.  In other words, the transmitter must
have the entire frame ready before initiating transfer. If the 'empty' signal
is asserted in the middle of a frame, the 'err' signal is reported back to
indicate the error condition. The consequence is that the current frame is
aborted.

## Unit testing in simulation
To make simulation time faster, I've added a new Makefile under
fpga/ethernet/lan8720a to perform a unit test just on the LAN8720A interface
module.  The testbench instantiates the interface module and simulates the
Ethernet PHY by simply looping back the Rx and Tx signals.  This loopback
works precisely because the Rx signals (rxd and crsdv) map directly
to the corresponding Tx signals (txd and txen).

The testbench generates transmit data, sends it through the transmit path of
the interface module, has the data loopback through the non-existing PHY, and
back into the receive path of the interface module, and finally stored in a
local signal.

The test sends two Ethernet frames through this setup, and verifies that both
frames come back out exactly as they were, with no error indications.

This test validates the operation of the interface, but does not verify the CRC
calculation. Only that it is consistent in both directions.

To run the simulation, run the command "make sim" in the directory
fpga/ethernet/lan8720a.

## Testing on hardware
Even though we have connected the signals at top level, we have not connected
the signals from the lan8720a interface module to the rest of the computer.
This will be the topic for the next two episodes.  However, since we now have
added the PHY signals to the top level, and we have added generation of clock
and reset, then the PHY will now be reset in default mode. This means that it
will autonegotiate link. Connecting the board to an Ethernet switch will allow
the PHY to establish link, and that will show up on the LED's on the board.

Furthermore, I've added a counter that will increment whenever an Ethernet
frame is received without any errors. This counter is shown on the overlay, and
should increment occasionally, whenever a broadcast frame is sent on the local
switch. You can induce such traffic by issuing a ping command to an unknown
IP address. This will send an ARP request once every second. The 'ETH' counter
in the overlay should increment, and you should see the link activity diode
on the Nexys4DDR board blink once every second. This little demonstration shows
that the CRC calculation is correct.

