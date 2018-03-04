#!/usr/bin/env python
import socket
import pprint

UDP_IP = "192.168.1.43"
UDP_PORT = 4660 

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))

cnt = 0
while True:
    cnt += 1
    data, addr = sock.recvfrom(1024) # buffer size is 1024 bytes
    print "received message:", cnt, ":", data.encode("hex")
