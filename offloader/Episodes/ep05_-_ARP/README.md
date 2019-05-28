# CPU offloader
# Episode 5 : "ARP"

Welcome to this fifth episode of "CPU offloader", where our design becomes able
to respond to ARP packets.

## Simulation

It makes sense to start with the simulation side of the design. I.e. how do we
actually test the design.

Like the previous episode, we test only the Ethernet module. So the testbench
tb\_eth instantiates a traffic generator (consisting of wide2byte and eth\_tx),
then feeds this data stream into the Ethernet module. The new addition in this
episode is to feed the data stream transmitted from the Ethernet module into a
traffic receiver (consisting of eth\_rx, strip\_crc, and byte2wide).

In this way, the actual test in lines 201-243 of tb\_eth becomes fairly simple.
It basically sends a hand-crafted ARP request into the Ethernet module, and
looks for a corresponding ARP response.  The contents of these hand-crafted
packets are based on the description of the ARP packet format found on
[wikipedia](https://en.wikipedia.org/wiki/Address_Resolution_Protocol).

Note the use of named ranges, e.g. R\_MAC\_TLEN. These ranges are defined in a
VHDL package in the file eth\_types.vhd. The reason for defining a separate
package with these constants is that the ARP module needs to use them as well.
Using a package avoids duplicating the information.

I've arbitrarily defined a MAC address and an IP address in lines 16-17 of the
test bench.

## ARP module

The interface to the ARP module (in lines 11-33 of arp.vhd) is chosen to make
the design as simple as possible.  In particular, the data stream in to and out
from the ARP module is the wide data stream, that connects easily to the
byte2wide and wide2byte modules.

The data width of 60 bytes is wide enough to contain the entire MAC header and
ARP packet. So all protocol fields are present in the same clock cycle.

Reception and protocol decoding is done in lines 60-66, and the response packet
is constructed in lines 68-79.

Note furthermore that the ARP module needs to know its own IP address and MAC
address. These are passed as generics in lines 12-15. This implies that they
must be known at compile time, and can not be changed dynamically. I did it
this way to keep the design simple.

An alternative could be to use e.g. DHCP to let the design discover its own IP
address, but that makes it more difficult for the host PC to know which IP
address the FPGA has been assigned. So simply hard-coding it is much easier.

The Ethernet standard requires a minimum frame size of 60 bytes (excluding
CRC).  Even though the ARP packet is smaller than 60 bytes (in fact only 42
bytes), the full 60 bytes must be sent, as shown in line 79.  If a smaller
frame size is used here, the host PC cannot receive the packets.

Finally, the ARP module drives the debug signal that gets shown on the VGA
output.  This happens in lines 85-97. I've chosen to show just the ARP packet
(28 bytes), including 4 trailing zero bytes.

## Ethernet module

The Ethernet module too gets passed the MAC address and IP address as generics
in lines 11-14.  These generics are just forwarded to the ARP module in lines
147-150.

To the Ethernet module I've added the instantiation of the new ARP module as
well as the wide2byte module. The latter is then connected to the eth\_tx
module. This completes the data path, from reception to transmission!

## Validation in hardware

Now comes the fun! Our design is able to receive and respond to ARP requests
for a specific IP address (hard-coded in line 36 of top.vhd). So after loading
the design into the FPGA, you can from the host PC issue the command "ping
192.168.1.77" and ...  nothing happens. Well, almost nothing. The ping command
won't work, because our design does not respond to ping (yet).

But it *does* respond to ARP requests, and you can verify that by issuing the
command "arp 192.168.1.77". This command should return with an indication that
the HW address associated with that IP is 00:11:22:33:44:55. And *that* is
success!

The data shown on the VGA output is part of the response being sent from the
FPGA.

