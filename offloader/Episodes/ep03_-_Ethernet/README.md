# CPU offloader
# Episode 3 : "Ethernet"

Welcome to this third episode of "CPU offloader", where we enable the
Ethernet port.

The overall idea is to have the design communicate with the host PC using the
Ethernet port. This will be developed over the next several episodes.

This episode is inspired by the corresponding episode [Episode 26 - Ethernet
Phy](https://github.com/MJoergen/nexys4ddr/tree/master/dyoc/Episodes/ep26_-_Ethernet_PHY)
in the DYOC tutorial.

## Architecture

The overall architecture of the system will consist of a receive path (ingress)
and a transmit path (egress).

We will be developing an Ethernet module that will be responsible for
interfacing to the Ethernet PHY and for implementing the necessary network
protocols (ARP, ICMP, and UDP).

In this episode, the Ethernet module handles the low-level interface to the
PHY. We'll leave the network protocols for the following episodes.

In the following I'll summarize the main development in this episode:

First of all, in the files top.vhd (lines 15-25) and top.xdc (lines 22-33)
we've added the pins connecting to the Ethernet Phy. In top.vhd the Ethernet
module is instantiated in lines 77-95.

## Ethernet module

The files for the Ethernet module are placed in the separate directory eth, and
the top level block for the Ethernet module is eth/eth.vhd. The Ethernet module
instantiates the eth\_rx and eth\_tx modules, which handle the ingress and
egress paths, respectively.

It seems worthwhile to go into some detail of the blocks eth\_rx and eth\_tx.
These blocks implement the low-level connection to the PHY, and provide a
client-side internal interface to the networking protocols. Both eth\_rx and
eth\_tx provide a byte-wide interface running at 50 MHz, and therefore support
a burst bandwidth of 400 Mbit/s, clearly much more than the 100 Mbit/s required
by the Ethernet PHY.

Note that I have made slight modifications to these modules, compared to
the DYOC tutorial.

### eth\_rx
The client interface (in lines 40-44) of the eth\_rx module is a so-called
"pushing" interface. The client is required to accept data at any time and any
rate as dictated by the eth\_rx module. This is because the eth\_rx module
cannot control when data is received by the Ethernet PHY. Notice how the client
has no way of controlling the transfer. There is no option for "back-pressure".
If the client needs to stop the data flow while e.g.  processing a packet, it
is up to the client to implement a buffering mechanism or to discard frames.

### eth\_tx
It is different with the eth\_tx module. This client interface (lines 52-57) is
a so-called "pulling" interface, where the client must make data available to
the eth\_tx module, but can not control the rate of transfer. Again, this is to
simplify the eth\_tx module.  When the client wants to send a frame of data,
the client will pull "empty" low, and this causes the eth\_tx module to start
transfer.  However, the Ethernet PHY requires a preamble to be sent first, and
therefore the eth\_tx module can not being consuming (reading) data until the
preamble is sent. And then one byte is consumed every four clock cycles only.
Therefore, it is the eth\_tx module that needs to control when data is
transferred.

The client is not allowed to pause in the middle of a frame, and therefore the
"empty" signal should not be pulled high until an entire frame is ready. This
means that the client is required to buffer a complete frame before initiating
transmission.

## Verification in simulation

It is very helpful during design and debugging to be able to simulate the
design before testing it in hardware. To this end, I've added a separate
simulation of just the Ethernet module.  This takes place in the testbench file
tb\_eth.vhd. To run the simulation, just type "make" in the eth directory.

To assist in simulation, and for future use, I've added two additional modules,
wide2byte.vhd and byte2wide.vhd, that can translate between a stream of bytes
and a stream of words, where the word size is configurable. In the testbench
the word size is set to 512 bits, i.e. 64 bytes. This is seen in the file
eth/tb\_eth.vhd lines 109-125 and 166-181.

### Byte-ordering
As soon as we concatenate several bytes together in a wider data bus, the issue
of byte-ordering becomes important. There is no right or wrong way of doing it,
but consistency and documentation are of course important. In this project I've
decided that the MSB byte of the wide data bus is the first byte transmitted or
received, regardless of the size of the frame or width of the data bus.

The up-side of this choice is that when viewing the result of simulations, the
contents of the wide data bus reads left-to-right.

### Wide data bus
The wide data bus uses the same interface as the byte-oriented data bus, except
that another signal "bytes" has been added. This contains the number of valid
bytes (starting from the MSB) that are valid in the current clock cycle.  A
value of 0 means that all bytes in the "data" signal are valid. The signal
"bytes" must be zero for all clock cycles, except when "last" is asserted.

### byte2wide
This module converts a stream of bytes into a wider bus interface.  Both the
input stream and the output stream use a pushing interface without
back-pressure. In my opinion, this is the easiest interface to work with.


## Clock domains

since the Ethernet module needs a 50 MHz clock, we generate this in line 60 of
top.vhd using the same clock divider method as for the VGA clock. The clock
must also be declared in line 38 of top.xdc.

Next, the Ethernet module provides a debug signal (currently just counting the
number of correctly received frames), but this signal (line 42 in top.vhd) is
synchronous to the Ethernet clock.  However, the VGA module requires a signal
synchronuous to the VGA clcok, and therefore we need a Clock Domain Crossing,
This is handled in lines 98-111 in top.vhd, where the cdc module is
instantiated.

Note how I choose to name the signals by prepending the name with the
correspoding clock domain, i.e.  all signals synchronous to the VGA clock are
prepended with vga\_, and similar for the Ethernet clock.  This naming
convention helps prevent errors with incorrect clock domain crossings.  Note
furthermore that only the top level module (and the cdc module) contain more
than one clock domain. All other modules consist of only a single clock domain
each. Again, this minimizes the opportunity for clock domain errors.

The Clock Domain Crossing module (cdc.vhd) is a wrapper for a Xilinx
Parameterized Macro (XPM), and these XPM's have to be explicitly enabled. This
is done in line 14 of the Makefile.

## Validation in hardware

Since we have no clients connected to the eth\_rx and eth\_tx modules yet, no
data is transferred yet. However, I've added in lines 53-70 of eth/eth.vhd a
simple counter to count the number of valid Ethernet frames received.

When running in hardware the VGA should display a counter that increments
occassionally, corresponding to each frame received. For instance, ping'ing a
non-existant IP address on the LAN will cause an ARP request to be broadcasted
once every second.

