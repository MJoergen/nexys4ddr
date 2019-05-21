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
traffic receiver (consisting of eth\_rx and byte2wide).

In this way, the actual test in lines 178-215 of tb\_eth becomes fairly simple.
It basically sends a hand-crafted ARP request into the Ethernet module, and
looks for a corresponding ARP response.  The contents of these hand-crafted
packets are based on the description of the ARP packet format found on
[wikipedia](https://en.wikipedia.org/wiki/Address_Resolution_Protocol).

## Ethernet module

The Ethernet module now contains hard-coded constants in lines 31-32 of eth.vhd
for the MAC address and IP address. Note that the IP address is hard-coded,
because the alternative (using e.g. DHCP) makes it more difficult for the
host PC to know which IP address the FPGA has been assigned. So simply
hard-coding it is much easier.

The Ethernet module instantiates the new ARP module, and I've moved the
instantiation of byte2wide from the Ethernet module to the ARP module. The
reason for this is because other protocols (e.g. UDP or ICMP), may wish to use
a different header size.  Likewise, generating the debug output signal is
handled by the ARP module too.

## ARP module

The ARP module implements an interface (in lines 17-28 of arp.vhd) that easily
connect to the eth\_rx and eth\_tx modules.

The ARP module basically instantiates the byte2wide and wide2byte modules, and
the actual packet processing takes place in a single process in lines 133-154.
Because of the wide data bus, the packet decoding and response generation can
all take place in a single clock cycle and in just a few lines of code.

The only caveat is that in line 170 the frame size must be (at least) 60 bytes.
This is because the Ethernet standard requires minimum 64 bytes of frame data
(including CRC) for every packet.

## Validation in hardware

Now comes the fun! Our design is able to receive and respond to ARP requests
for a specific IP address (hard-coded in line 32 of eth.vhd). So after loading
the design into the FPGA, you can from the host PC issue the command "ping
192.168.1.77" and ...  nothing happens. Well, almost nothing. The ping command
won't work, because our design does not respond to ping (yet).

But it *does* respond to ARP requests, and you can verify that by issuing the
command "arp 192.168.1.77". This command should return with an indication that
the HW address associated with that IP is 00:11:22:33:44:55. And *that* is
success!

