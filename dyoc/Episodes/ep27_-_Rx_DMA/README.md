# Design Your Own Computer
# Episode 27 : "Rx DMA"
 
Welcome to "Design Your Own Computer".  In this episode we'll add the Rx DMA to
allow the CPU to process frames received on the Ethernet port.

In this and the following episodes we'll build a web-server on the Nexys 4 DDR
board.

## Frame format in memory
The implementation I've chosen here has the FPGA writing the received Ethernet
frames directly to RAM, without requiring any assistance from the CPU.  This is
called Direct Memory Access. To make this work we must allocate a certain area
in memory and design an Rx DMA module to write to this memory area.

Then we must decide on a format of the data written to the memory.  Initially,
we have three requirements:
* We must be able to distinguish where one frame ends and another frame begins. 
* Each frame must be in a contiguous (un-fragmented) block of memory.
* The design must be robust and handle error situations gracefully.

I've chosen to prepend each frame with a two-byte header that contains the
total number of bytes in the frame, including the header. This allows the
software to easily determine where the next frame begins, and thus takes care
of the first requirement above.

Note that the length field therefore serves two different purposes: It
indicates the length of the current frame, and it is used to calculate the
beginning of the next frame. The latter assumes that frames are back-to-back.

To ensure the second requirement, I've decided to use bit 15 in the length
field as follows:
* bit 15 = 0: The next frame starts right after this frame
* bit 15 = 1: The next frame starts at the beginning of the receive buffer.

In other words, it is the Rx DMA that decides where the next frame starts, and
indicates this in the two-byte header. Software must correctly decode this
header to calculate the start of the next frame.

## Interface to CPU
The CPU is responsible for allocating memory for the receive buffer. The CPU
must then instruct the Rx DMA where the receive buffer is located. On the other
hand, the Rx DMA must instruct the CPU when a new frame has been written into
this receive buffer.  This leads to the following memory mapped registers:
* ETH\_START  : Address of first byte of receive buffer.
* ETH\_END    : Address of last byte of receive buffer plus one.
* ETH\_ENABLE : One bit to enable/disable the Rx DMA.
* ETH\_WRPTR  : Address of last byte written to memory plus one.
* ETH\_RDPTR  : The current CPU read pointer.

Both the write pointer ETH\_WRPTR and the read pointer ETH\_RDPTR will point to
addresses within the allocated receive buffer, i.e. between ETH\_START and
ETH\_END inclusive.

In others words ETH\_WRPTR points to the first byte of the next frame (not yet
received), whereas ETH\_RDPTR points to the first byte of the current frame.
When ETH\_WRPTR and ETH\_RDPTR are equal, then the receive buffer is completely
empty.

When the Rx DMA writes to the receive buffer, it must ensure that ETH\_WRPTR
never reaches ETH\_RDPTR. So the receive buffer is full, when ETH\_WRPTR =
ETH\_RDPTR - 1.

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
interfaces faster than can be processed. In the current implementation a simple
overflow occurs leading to a persistent error that can only be cleared by
reset.

### Header insertion
This is handled in ethernet/rx\_header.vhd. This module takes care of:
* Prepending 2 bytes of header containing total number of bytes in this frame.
* Maintaining statistics counters of received good and bad frames.
* Discarding bad frames (e.g. incorrect CRC).

This module operates in a store-and-forward mode, where the entire frame is
stored in an input buffer, until the last byte is received. This input buffer
can contain any number of frames, but only a total amount of 2 Kbyte of data.
It is therefore important, when designing the system, that we know how to
handle buffer overrun.

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
so the output is much faster than the input. However, if the receiver does not
accept any data, then the ring buffer can indeed overflow.

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
in rx\_header.vhd will fill up and generate the persistent error eth\_overflow.

## Updates to the memory block
Since we now have two independent processes writing to the memory, i.e. the CPU
and the Ethernet DMA, we need an arbitration between them. I've chosen to give
the Ethernet DMA priority over the CPU, but at the same time, limit the DMA to
only writing every second clock cycle. That way, the CPU will have to wait at
most one clock cycle for a write to complete.

The extra wait state is inserted in line 113 in mem/mem.vhd. The arbitration
between CPU and DMA is handled in lines 128-140.

## Unit testing in simulation
Due to the complexity it is beneficial to have a separate testbench to just
test this new data path. So the testbench will be ethernet\_tb.vhd and will
test the Ethernet wrapper module.

In order to generate traffic on the Ethernet port, a PHY simulator will be used.

## Test program to run on hardware
The program enters a busy loop polling the write pointer from the DMA. When
the write pointer is updated an entire Ethernet frame has been received. The
firdt 16 bytes (including the 2 byte length field) are printed to screen,
and the read pointer is updated.

Note that the value read from the write pointer may not be valid, due to
a race condition. Because the CPU accesses the memory only 1 byte at a time,
the write pointer may be updated between reading the first and the second
byte. Instead, the CPU relies on the correctness of the length field.

Note also that the receiver effectively operates in promiscuous mode, i.e.
performs no filtering of MAC addresses. This is not really necessary,
because the Nexyx board is connected to a switch, and the switch performs
automatically the MAC address filtering.

