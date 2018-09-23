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
(lines 39-49) we add the ports to our entity declaration, and we must remember
to add them to the constraint file comp.xdc (lines 39-50) as well. The signal
names and pin names are copied from the schematic linked to above.

## Clocking
In most designs, the clocks are determined by the external interfaces. This
design is no exception.  So far we've had to interface to the VGA output at 25
MHz, Now we additionally have to interface to the Ethernet PHY, which runs at
50 Mhz. So our design will now contain two different "clock domains", i.e.
different areas of the design will be controlled by different clocks.

The Ethernet clock is generated in comp.vhd (line 138) using the same clock
divider as for the VGA clock. Additionally, all clock signals must be described
in the constraint file as well, i.e. in comp.xdc line 58.

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

Note how the write side has a wr\_afull\_o port. It is up to the user not to
write any more data to the fifo, when this signal is asserted. However, if it
does happen then the wr\_error\_o port will be asserted (and latched).
Similarly, the read side has a rd\_empty\_o port. Data should not be read from
the fifo when this signal is asserted. Again, an error signal is latched on
rd\_error\_o.

It is fairly straightforward to design the system so that one doesn't read
from an empty fifo. However, avoiding writing to a full fifo requires an
understanding of the global system architecture. One must consider, whether the
receiver can pull data out of the fifo quickly enough, compared to how fast
data it pushed into the fifo. This also influences the choice of how big the
fifo should be. In general, one should consider how to handle situations where
data is received faster than can be processed. In the current implementation a
simple overflow occurs leading to a persistent error that can only be cleared
by reset.

## Overall design strategy for receiving data from the Ethernet.
The implementation I've chosen here has the FPGA writing the received
Ethernet frames directly to RAM, without requiring any assistance from the CPU.
This is called Direct Memory Access. To make this work we must allocate a
certain area in memory and configure the DMA block to write only to this
memory area.

Then we must decide on a data format. Particularly, we must be able to
distinguish where one frame ends and another frame begins.  I've chosen to
prepend each frame with a two-byte header that contains the total number of
bytes in the frame, including the header.

The design must also be robust and handle error situations gracefully, e.g.  by
discarding frames that have an incorrect CRC.

A number of blocks is needed in the design in order to facilitate all this.  In
the following sections each block will be described in detail.  The list of
blocks are:
* Interface to the Ethernet PHY - generating a byte stream with Start-Of-Frame
and End-Of-Frame markers, see lan8720a/rmii\_rx.vhd.
* Header insertion - this strips away the CRC (and validates it), and inserts
two bytes in front of the packet with the total byte length, see strip\_crc.vhd
* A fifo to provide for crossing from the Ethernet clock domain to the CPU
clock domain, see fifo.vhd.
* A DMA to write the data to the memory, see dma.vhd.

All the above files are placed in the directory 'ethernet', and connected
together in the wrapper file ethernet/ethernet.vhd.

### Interface to the Ethernet PHY (Data reception)
The PHY chip connects to the FPGA using the [RMII
specification](https://en.wikipedia.org/wiki/Media-independent_interface#Reduced_media-independent_interface).
So the first task is to convert this interface to something that fits easily
into the fifo (needed for the clock domain crossing).

This is handled in ethernet/lan8720a/rmii\_rx.vhd.  This module takes care of:
* 2-bit to 8-bit expansion (user data is output every fourth clock cycle @ 50 Mhz).
* CRC validation.
* Framing with SOF/EOF.

The output from this block is one byte pr. clock cycle, with SOF asserted on the
first byte of the MAC header and EOF asserted on the last byte of the CRC. Two
error bits are provided (valid only at EOF) that indicate either a receiver
error or a CRC error.

### Header insertion
This is handled in ethernet/strip\_crc.vhd. This module takes care of:
* Stripping away 4 bytes of CRC at end of frame.
* Prepending 2 bytes of header containing total number of bytes in this frame.
* Maintaining statistics counters of received good and bad frames.
* Discarding bad frames (containing errors, e.g. bad CRC).

This module operates in a store-and-forward mode, where the entire frame is
stored in an input buffer, until the last byte is received. This input buffer
can contain any number of frames, but only a total amount of 2 Kbyte of data.
The buffer is actually a ring buffer, with a write pointer and a read pointer.
When either pointer reaches the end of the buffer, the pointers wrap around to
the beginning. Since the buffer size is a power of 2, no extra logic is
required to implement this wrap-around.

The address of the first byte of the frame (SOF) is stored in the register
start\_ptr.  If the frame is to be discarded, the current write pointer is
reset to this start\_ptr.

The address of the last byte of the frame (EOF) is stored in a separate FIFO.
This is used to calculate the length of the frame.

The data rate into this block is one byte every fourth clock cycle @ 50 MHz
(corresponding to 100 Mbit/s).  The output rate is one byte every clock cycle,
so the output is much faster than the input.  There should therefore be no risk
of buffer overflow. Overflow can really only happen if a single frame larger
than 2K is being received or if the fifo is full. The current implementation
does not handle this situation, and will fail miserably.  However, maximum
frame size on Ethernet is 1500 bytes, so this should not occur.

Inputs to this block are taken directly from the rmii\_rx block. However, the
additional signal rx\_enable\_i is used to enable discarding of all frames.
This is needed when configuring the DMA, see below.

Another input to this block is out\_afull\_i, which is used as flow-control.
When this signal is asserted, the fifo that comes next in line is full, and can
accept no more data at the moment. This signal prevents reading from the input
buffer, and if it is asserted for too long will cause the input buffer to
overflow.

### Clock crossing fifo
This is handled in ethernet/fifo.vhd. This module takes care of:
* Instantiating a Xilinx fifo primitive.
* Latching read and write errors.

### DMA
This is handled in ethernet/dma.vhd. This module takes care of:
* Generating write requests to CPU memory.
* Maintaining a write pointer.

As mentioned above, the CPU is responsible for allocating (e.g. using malloc) a
chunk of contiguous memory, and configuring the DMA block. This is done by
writing the start and end of the receive DMA buffer.  The DMA must be disabled
while modifying these pointers.

Whenever data is received on the Ethernet port, the DMA will write data to the
buffer, always maintaining a write pointer to instruct the CPU how much data
has been received. The writer pointer seen by the CPU is updated only when a
frame has been completely received and written to memory.  Likewise, the CPU
maintains a read pointer to instruct the DMA where it is allowed to write to.
This prevents the DMA from overwriting data the CPU has not yet processed.

The whole design is put together in the file ethernet/ethernet.vhd.

A choice must be made on how to handle the situation where the receive DMA
buffer runs full, e.g. if the CPU is too slow in processing a packet, while a
burst of subsequent packets are received. The current implementation will stop
reading from the fifo (the signal user\_rden remains low), which will then fill
up (as indicated by the signal eth\_fifo\_afull). Eventually the input buffer
in strip\_crc.vhd will fill up and generate the persistent error eth\_overflow.

## Updates to the memory block
Since we now have two independent processes writing to the memory, i.e. the CPU
and the Ethernet DMA, we need an arbitration between them. I've chosen to give
the Ethernet DMA priority over the CPU, but at the same time, limit the DMA to
only writing every second clock cycle. That way, the CPU will have to wait at
most one clock cycle for a write to complete.

The extra wait state is inserted in line 113 in mem/mem.vhd. The arbitration
between CPU and DMA is handled in lines 128-140.
