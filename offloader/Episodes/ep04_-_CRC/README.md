# CPU offloader
# Episode 4 : "CRC"

Welcome to this fourth episode of "CPU offloader", where we proceed with the
next step towards implementing the network protocols required for this project.

## Architecture

Generally, I prefer having many small modules, where each module serves a
single purpose.

Let's begin with the receive path. The eth\_rx module provides a byte stream of
data from each frame. If any errors occur during reception, the frame is ended
with the "ok" signal de-asserted. In this case, the contents of the frame are
not reliable, and must be discarded.  This is the purpose of the strip\_crc
module described in the following.

## strip\_crc
To make it easier for the client of the strip\_crc module, I've chosen to have
the strip\_crc module discard frames with any errors, including CRC errors.
This means that the strip\_crc module must buffer up the entire frame
(including CRC), and only at the end of the frame, when "last" is asserted,
should it sample "ok" and possibly discard the entire frame. The internal
buffer within the strip\_crc module must therefore be able to contain a
complete Ethernet frame.

The maximum size of an Ethernet frame is 1518 bytes (including CRC).  I've
chosen an implementation where the entire frame is stored in a Block RAM, which
can hold up to 2K bytes.

The Block RAM acts as a circular ring buffer, with a write pointer controlling
where the next byte of data is written to. This is similar to the write side of
a regular FIFO. However, reading from the memory does not commence until the
entire frame has been written to memory. Then "ok" is sampled.

If the CRC is valid, the frame must be forwarded, and this module starts
reading from the memory and updates the corresponding read pointer. However, if
the CRC is invalid, the frame must be discarded. This is done by resettting the
write pointer to the beginning of the frame, thereby effectively overwriting
the errored frame.

Therefore this module needs, besides a write pointer and a read pointer, also a
start pointer indicating the start of the currect frame, i.e. whereto the write
pointer should possibly be reset, and an end pointer to control when to stop
reading more data.

Now, it can happen that a single long frame is followed by several small
frames, and since the reading only commences after the long frame has been
received, the end pointers of the following frames must be stored somewhere.
This is what the ctrl\_fifo is for - to store the pointers to the last byte of
each received frame.

Using a FIFO for the end pointers is just one possible implementation. The
purpose of this FIFO is really just to determine where one frame ends and a new
frame begins.  Therefore, an alternative could be to store the control signal
"last" along the "data" signal in the ring buffer. However, you would still
need some way to signal that the ring buffer contains a complete and valid
frame. because only then may reading from the buffer commence.

### Buffer overflow

A note about bandwidth.  Whenever a buffer is used, one should always consider
the possibility of overflow. Can we reach a situation, where the ring buffer is
full?  Should we check for it? How should we react in such a situation?

Well, if a maximum sized frame is received, the buffer will fill up to 1518
bytes, and then reading will commence. However, reading from the buffer is done
one byte every clock cycle, i.e. at a rate of 400 Mbit/s, whereas writing
happens only at a rate of 100 MBit/s. Since reading is faster than writing, the
buffer can never overflow, unless we receive an illegally large frame (2K bytes
or larger). However, to simplify the design I've decided to ignore this
possibility completely.

Note furthermore, that we have chosen here to require the client to always
accept data.  In other words, it is the clients responsibility to always be
ready to receive data.

We could alternatively allow the client to signal back to strip\_crc an
indication of "don't send more data just now", a.k.a. "back-pressure". However,
then suddenly the possibility of buffer overflow becomes very real, and this
would therefore add complexity to this module. So to follow the principle of
small and simple modules, I've chosen to exlude the complexity of
"back-pressure" from this module, and instead deny the client the possibility
of applying back-pressure.

## Simulation

The testbench is changed to now instantiate the Ethernet module. We use the
modules wide2byte and eth\_tx to generate the data stream received from the
Ethernet PHY. Since we still don't have any transmit path implemented, I've
chosen to sample the received frame header and present them on the debug output
signal.

The simulation injects two short frames into the Ethernet module from the PHY
and inspects the debug output.

## Validation in hardware

Our design can still not send any frames, and can still not do anything meaningfull
with the received data. However, using the above blocks it is now possible
to display on the VGA output a snapshot of the last received frame.

In lines 62-81 of eth/eth.vhd we select byte numbers 10-41 (incl) of the
received frame.  This conveniently gives us the entire ARP header plus four
bytes of the MAC header.  ARP packets can easily be recognized on the screen by
looking for xxxx0806 in the beginning.

Issuing a ping command on the host PC to an unknown IP address will generate a
series of ARP requests, usually once every second. The last four bytes
displayed on the VGA output will (in case of an ARP request) be the unknown IP
address requested.

