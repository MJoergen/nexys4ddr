# CPU offloader
# Episode 7 : "UDP"

Welcome to this seventh episode of "CPU offloader", where our design becomes able
to respond to UDP packets.

## UDP processing

The design I've chosen is to have a generic UDP processing module in udp.vhd
that processes incoming UDP frames and extracts the payload to a client.
Similarly, the UDP module receives a payload from the client and encapsulates
it into an UDP frame to be sent.

## UDP client

The interface from the UDP module to the UDP client is the same as before, i.e.
a 60 byte wide bus interface.

The current design has a very simple client (inverted.vhd) that bit-wise
inverts the received payload and sends it back.

## Other changes

I've added the UDP protocol decoding information in the file eth\_types.vhd.
The UDP port number to use has been added in the file top.vhd and the test
bench eth/tb\_eth.vhd.

The UDP module (like the ARP and ICMP modules) is instantiated within the eth
module.  However, the UDP client (here inverter.vhd) is instantiated from the
top module and simultaneously from the test bench.

## UDP module
The UDP module contains a receive path (Ethernet to client) and a transmit path
(client to Ethernet). These two paths are almost completely separate, except
that the receive path stores the header needed in the transmit path. In
particular the UDP response header is not sent until the client has data to
send.  This design allows the client to send multiple replys to a single
request.

## Testing in simulation
The test bench has been updated to send a single small UDP frame and verifies
it receives a small UDP frame as response.

## Testing in hardware
Since the design can now receive and send UDP frames, I've chosen to write a
small python program main.py to verify this. It sends a small UDP frame to the
FPGA and prints out whatever it receives as response.

## Future
The current design uses about 7% of the logic in the FPGA (specifically, about
1081 out of 15850 slices). So there is still a large available area in the FPGA
to implement the actual offloading functions needed.

