# Design Your Own Computer
# Episode 27 : "Rx DMA"
 
Welcome to "Design Your Own Computer".  In this episode we'll add the Rx DMA to
allow the CPU to process frames received on the Ethernet port.

In this and the following episodes we'll build a web-server on the Nexys 4 DDR
board.

## Frame format in memory
The implementation I've chosen here has the FPGA writing the received Ethernet
frames directly to RAM, without requiring any assistance from the CPU (except
being told where in memory to write).  This is called Direct Memory Access. To
make this work we must allocate a certain area in memory and design an Rx DMA
module to write to this memory area.

Then we must decide on a format of the data written to the memory.  Initially,
we have four requirements:
* Only one frame is written to this chunk of memory.
* We must be able to know, when a complete frame has been written.
* We must be able to know the size of the frame (i.e. number of bytes).
* We must be able to instruct the Rx DMA when we're finished reading the frame.

The first requirement is made to keep the design as simple as possible. It is
certainly possible to relax this requirement: For instance, allowing multiple
frames written to memory back-to-back could lead to better performance.
However, this episode is going to be very long anyway, so no need to complicate
matters more. Performance is not a primary concern in this design!

I've chosen to prepend each frame with a two-byte header that contains the
total number of bytes in the frame, including the header. This allows the
software to easily determine the number of bytes in the frame.

The buffer space needed has to accommodate a full Ethernet frame incl header, i.e.
1516 bytes. The Rx DMA will discard any frames that are longer than that.

## Interface to CPU
The CPU is responsible for allocating memory (at least 1516 bytes) for the
receive buffer. The CPU must then instruct the Rx DMA where the receive buffer
is located and that the CPU is ready to receive the next Ethernet frame. On the
other hand, the Rx DMA must instruct the CPU when a new frame has been written
into this receive buffer.  This leads to the following memory mapped registers:
* ETH\_RXDMA\_ENABLE (R/W) : One bit to control the "owner" of the receive buffer.
* ETH\_RXDMA\_PTR    (R/W) : Address of first byte of receive buffer.

When the CPU has allocated the memory for the receive buffer and written the
address to ETH\_RXDMA\_PTR, the CPU may now write the value '1' to
ETH\_RXDMA\_ENABLE.  This instructs the Rx DMA that it is now the "owner" of the
buffer and may write data there. When an entire Ethernet frame has been written
(including 2 byte header), the Rx DMA automatically clears the
ETH\_RXDMA\_ENABLE.

As long as ETH\_RXDMA\_ENABLE is zero, the CPU "owns" the receive buffer, and the
Rx DMA will not write any data. When the CPU has finished processing the
received frame, the CPU may repeat the process by once again writing a '1' to
ETH\_RXDMA\_ENABLE.

Any Ethernet frames received while ETH\_RXDMA\_ENABLE is cleared will be stored
in internal FIFOs as explained below.

## Overall design strategy for receiving data from the Ethernet.
A number of blocks is needed in the design in order to facilitate all this.  In
the following sections each block will be described in detail.  The list of
blocks are:
* Header insertion - this discards packets with errors and inserts two bytes
  in front of the packet with the total byte length, see rx\_header.vhd.
* A fifo for crossing from the Ethernet clock domain to the CPU clock domain,
  see fifo.vhd. More about this in the next section.
* An Rx DMA to write the data to the memory, including figuring out where in
  memory, see rx\_dma.vhd.

All the above files are placed in the directory 'ethernet', and connected
together in the wrapper file ethernet/ethernet.vhd.

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
usually a good idea to create wrappers around vendor-specific primitives,
because it makes it possible to migrate the design to other boards later.
Additionally, it gives us the option to choose more descriptive port names and
improved error handling.  Note how the fifo has two different clocks, one for
the write port and one for the read port.

Note how the write side has a wr\_afull\_o port. It is up to the user not to
write any more data to the fifo, when this signal is asserted. However, if it
does happen then the wr\_error\_o port will be asserted (and latched).
Similarly, the read side has a rd\_empty\_o port. Data should not be read from
the fifo when this signal is asserted. Again, an error signal is latched on
rd\_error\_o.

It is fairly straightforward to design the system so that one doesn't read from
an empty fifo. However, avoiding writing to a full fifo requires an
understanding of the global system architecture. Additionally, when designing
with fifos one must consider, whether the receiver can pull data out of the
fifo quickly enough, compared to how fast data is pushed into the fifo. This
also influences the choice of how big the fifo should be. In general, one
should consider how to handle situations where data is received from external
interfaces faster than can be processed.

A choice must be made on how to handle the situation where the receive DMA
buffer runs full, e.g. if the CPU is too slow in processing a packet, while a
burst of subsequent packets are received. The current implementation will stop
reading from the fifo (the signal user\_rden remains low), which will then fill
up (as indicated by the signal eth\_fifo\_afull). Eventually the input buffer
in rx\_header.vhd will fill up and subsequent frames will be discarded and counted
as overflow.

### Header insertion
This is handled in ethernet/rx\_header.vhd. This module takes care of:
* Prepending 2 bytes of header containing total number of bytes in this frame.
* Maintaining statistics counters of received good and bad frames, as well as
  overflow.
* Discarding bad frames (e.g. incorrect CRC or oversize).

This module operates in a store-and-forward mode, where the entire frame is
stored in an input buffer, until the last byte is received. This input buffer
can contain any number of frames, but only a total amount of 2 Kbyte of data.
It is therefore important, that this buffer can be emptied quickly before
another frame fills up the buffer. Furthermore, when designing the system, we
need to know how to handle buffer overrun.

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
so the output is much faster than the input. However, if the output receiver
does not accept any data, then this ring buffer can indeed overflow.

Inputs to this block are taken directly from the rmii\_rx block. However, the
additional control signal rx\_enable\_i is used to enable discarding of all
frames.  This is needed when configuring the RxDMA, see below.

Another input to this block is out\_afull\_i, which is used as flow-control.
When this signal is asserted, the fifo that comes next in line is full, and can
accept no more data at the moment. This signal prevents reading from the input
buffer, and if it is asserted for too long will cause the input buffer to
overflow.

### Clock crossing fifo
This is handled in ethernet/fifo.vhd. This module takes care of:
* Instantiating a Xilinx fifo primitive.
* Latching read and write errors.

### Rx DMA
This is handled in ethernet/rx\_dma.vhd. This module takes care of:
* Generating write requests to CPU memory.
* Maintaining a write pointer.
* Synchronizing with the CPU about who "owns" the receive buffer.

As mentioned above, the CPU is responsible for allocating (e.g. using malloc) a
chunk of contiguous memory, and configuring the DMA block. This is done by
writing the start of the receive DMA buffer.

When the CPU is ready to receive an Ethernet frame, it writes to RXDMA\_ENABLE,
which asserts the signal dma\_enable\_i.  When the frame has been written to
RAM, the Rx DMA asserts the signal dma\_clear, which resets the register
RXDMA\_ENABLE.

## Updates to the memory block
Since we now have two independent processes writing to the memory, i.e. the CPU
and the Ethernet DMA, we need an arbitration between them. I've chosen to give
the Ethernet DMA priority over the CPU, but at the same time, limit the DMA to
only writing every second clock cycle. That way, the CPU will have to wait at
most one clock cycle for a write to complete.

The extra wait state is inserted in line 113 in mem/mem.vhd. The arbitration
between CPU and DMA is handled in lines 128-140.

Additionally, the Rx DMA needs to be able to clear the RXDMA\_ENABLE register.
This means modifying the memio module.

## Unit testing in simulation
Due to the complexity it is beneficial to have a separate testbench to just
test this new data path. So the testbench will be ethernet\_tb.vhd and will
test the Ethernet wrapper module.

In order to generate traffic on the Ethernet port, a PHY simulator will be
used.  Furthermore, a RAM simulator is added to receive the data written by the
Rx DMA.

## Test program to run on hardware
The program enters a busy loop polling the write pointer from the DMA. When
the write pointer is updated an entire Ethernet frame has been received. The
first 16 bytes (including the 2 byte length field) are printed to screen,
and the read pointer is updated.

Note that the value read from the write pointer may not be valid, due to
a race condition. Because the CPU accesses the memory only 1 byte at a time,
the write pointer may be updated between reading the first and the second
byte. Instead, the CPU relies on the correctness of the length field.

Note also that the receiver effectively operates in promiscuous mode, i.e.
performs no filtering of MAC addresses. This is not really necessary,
because the Nexys board is probably connected to a switch, and the switch
performs essentially all the necessary MAC address filtering.

