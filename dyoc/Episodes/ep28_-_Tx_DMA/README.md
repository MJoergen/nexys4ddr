# Design Your Own Computer
# Episode 28 : "Tx DMA"
 
Welcome to "Design Your Own Computer".  In this episode we'll add the Tx DMA to
allow the CPU to send Ethernet frames.

In this and the following episodes we'll build a web-server on the Nexys 4 DDR
board.

## Interface to CPU
The process of sending a frame is similar to receiving a frame:
* The CPU writes the frame in memory, prepended with a two-byte header
  containing length of frame excluding header.
* The CPU writes the address of the header to the ETH\_TXDMA\_PTR register.
* The CPU writes 1 to the ETH\_TXDMA\_ENABLE register.
* When the Tx DMA has finished reading the frame from memory, it will
  automatically clear the register ETH\_TXDMA\_ENABLE.

And that's it!

To make this work a new file tx\_dma.vhd is added.
Furthermore, a number of new signals have been added to the memio module.

## Testing in simulation
The unit testbench ethernet\_tb has been modified. Now frames are initiated
from the Tx DMA, sent out to the PHY, and then looped back into the FPGA and
received via the Rx DMA.

The main testbench tb has been modified too. Here frames are received from the
PHY, written to memory by the Rx DMA, processed by the CPU and a new frame sent
for tranmission via the Tx DMA, and finally sent out to the PHY.

## Testing in hardware
The test program prog/ethernet/ethernet.c is written to respond to ARP requests
for the IP address 192.168.1.77. This means that issuing a ping to this address
from the host machine to the FPGA board will result in an ARP request being
sent towards the FPGA board and an ARP reply being sent back to the host
machine. Afterwards, the ARP table on the host machine should be updated, which
can be verified with the shell command "arp -a".

In the next episode, we'll build the software necessary to be able to properly
respond to a ping command.

