# CPU offloader
# Episode 4 : "Network protocols - part 1"

Welcome to this fourth episode of "CPU offloader", where we partially implement
the network protocols ARP and UDP.

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
(including CRC), and only at the end of the frame, when "eof" is asserted,
should it sample "ok" and possibly discard the entire frame. The internal
buffer within the strip\_crc module must therefore be able to contain a
complete Ethernet frame.

The maximum size of an Ethernet frame is 1518 bytes (including CRC).  I've
chosen an implementation where the entire frame is stored in a Block RAM, which
can hold up to 2K bytes.

The Block RAM acts as a circular ring buffer, with a write pointer controlling
where the next byte of data is written to. This is similar to the write side of
a regular FIFO. However, reading from the memory does not commence until the
entire frame has been writte to memory. Then "ok" is sampled.

If the CRC is valid, the frame must be forwarded, and this module starts
reading from the memory and updates the corresponding read pointer. However, if
the CRC is invalid, the frame must be discarded. This is done by resettting the
write pointer to the beginning of the frame, thereby effectively overwriting
the errored frame.

Therefore, this module needs, besides a write pointer and a read pointer, also
a start pointer indicating the start of the currect frame, i.e. whereto the
write pointer should possibly be reset. And also an end pointer, to control
when to stop reading more data.

Now, it can happen that a single long frame is followed by several small
frames, and since the reading only commences after the long frame has been
received, the end pointers of the following frames must be stored somewhere.
This is what the ctrl\_fifo is for - to store the pointers to the last byte of
each received frame.

Using a FIFO for the end pointers is just one possible implementation. The
purpose of this FIFO is really just to determine the correct control signals,
i.e.  "sof" and "eof". Therefore, an alternative would be to store these two
control signals along the "data" signal in the ring buffer. However, you would
still need some way to signal that the ring buffer contains a complete and
valid frame. because only then may reading from the buffer commence.

A note about bandwidth.  Whenever a buffer is used, one should consider the
possibility of overflow. Can we reach a situation, where the ring buffer is full?
Should we check for it? How should we react in such a situation?

Well, if a maximum sized frame is received, the buffer will fill up to 1518
bytes, and then reading will commence. However, reading from the buffer is done
one byte every clock cycle, i.e. at a rate of 400 Mbit/s, whereas writing
happens only at a rate of 100 MBit/s. Since reading is faster than writing, the
buffer can never overflow.

Note furthermore, that we have chosen here to require the client to always
accept data.  In other words, it is the clients responsibility to always be
ready to receive data.

We could alternatively allow the client to signal back to strip\_crc an
indication of "don't send more data just now", aka "back-pressure". However,
then suddenly the possibility of buffer overflow becomes very real, and this
would therefore add complexity to this module. So to follow the principle of
small and simple modules, I've chosen to exlude the complexity of
"back-pressure" from this module, and instead deny the client the possibility
of applying back-pressure.

## ser2par

Once we have a valid frame, stripped of the CRC, we want some way to do further
processing. I've found that it is cumbersome having a one-byte-at-a-time
interface, so I've added a Serial-To-Parallel translation block ser2par. The
purpose of this block is to extract a fixed-size header and output this header
as a single wide vector.  The remaining data is forwarded one-byte-at-a-time.

The idea is to extract (remove), say, the MAC, IP, and UDP headers
simultaneously, to allow easy examination of the headers to determine the
further course of action.  The remaining payload can then perhaps be subjected
to another iteration of ser2par, if the need be.

The implementation of ser2par is fairly straight-forward. Note that I have
chosen an implementation based on a large shift-register, see line 63. This
uses the least amount of logic.  Alternatively, I could have chosen to write to
a variable position, i.e. something like 
    hdr_data_r(8\*byte_cnt+7 downto 8\*byte_cnt+) <= rx_data_i;
However, this would use additional resources for the byte\_cnt signal and for
the associated multiplexing when accessing a variable range of bits in a large
vector.

## Byte-ordering

Experience has shown me that it is necessary to consider byte-ordering. There is
no right or wrong, only you have to document what you decide.

## Validation in hardware

Our design can still not send any frames, and can still not do anything meaningfull
with the received data. However, using the above blocks it is now possible
to display on the VGA output a snapshot of the last received frame.

In lines 64-79 of eth/eth.vhd we select byte numbers 10-41 (incl) of the frame.
This conveniently gives us the entire ARP header plus four bytes of the MAC
header.  ARP packets can easily be recognized on the screen by looking for
xxxx0806 in the beginning.

Issuing a ping command on the host PC to an unknown IP address will generate a
series of ARP requests, usually once every second. The last four bytes
displayed on the VGA output will (in case of an ARP request) be the unknown IP
address requested.

