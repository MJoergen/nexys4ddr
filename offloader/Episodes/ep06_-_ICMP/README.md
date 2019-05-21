# CPU offloader
# Episode 6 : "ICMP"

Welcome to this sixth episode of "CPU offloader", where our design becomes able
to respond to ICMP packets.

## ICMP

Just like the last episode in this episode we write a separate module ICMP
whose responsibility is to check incoming packets and - in case of an ICMP
request - send an appropriate response.

The ICMP module instantiates - just like the ARP module - the byte2wide block
to make it easier to decode incoming packets and generating the response, which
is the sent through the wide2byte module, again just like the ARP module.

A complication is that the IP header and the ICMP header includes a checksum
that must be valid. So I've decided to make use of a simple state machine,
where the response is first generated (with zeroes in place of the checksums),
and in the second stage the checksums are evaluated.

Calculating the checksum is in this particular case, because of the limited
amount of data to checksum, relatively easy. It is therefore done entirely
combinatorial, see lines 138-151 of icmp.vhd.

## Multiplexing

Now that we have two blocks generating packets for transmission, ARP and ICMP,
we need a way to multiplex between them. So far, I've done the very lazy and
simple approach, where I assume that the two blocks will never send data
simultaneously. I do this by essentally performing an OR of the output from the
blocks.

This lazy approach will work most of the time, but it is possible to create
situations where both blocks will try to send at the same time. In this case
the approach used here will send corrupted packets.

The lazy multiplexer is implemented in lines 186-199 of eth.vhd.

## Sihulation
Since our implementation checks the validity of the IP and ICMP checksums, our
test bench must make sure that the pakets sent to the DUT contain the correct
checksums too. The checkusm function is therefore copied to tb\_eth.vhd, where
the same two-stage approach of generating packets is used, see line 220-229.
