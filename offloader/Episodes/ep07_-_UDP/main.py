#!/usr/bin/env python
import socket

# Open a UDP socket
sock = socket.socket(socket.AF_INET,    # Internet
                     socket.SOCK_DGRAM) # UDP

# IP address and port number of the FPGA device
DUT = ("192.168.1.77", 4660)

# Test inverter module
message = "ABC"

print "Sending message:",message.encode("hex")
sock.sendto(message, DUT)

data, server = sock.recvfrom(1500)
print "Received message:",data.encode("hex")
