#!/usr/bin/env python
import socket
import pprint

UDP_IP = "192.168.1.43"
UDP_PORT = 4660 

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))

output_file = open("frames.bin", "wb")

def write_frame(data):
    assert (len(data) % 2) == 0
    vals = []
    for i in range(len(data)/2):
        vals += [data[i*2+1]]*(1+data[i*2])
    assert len(vals) == 1280
    output_file.write(vals)


sync = False
cnt = 0
while True:
    cnt += 1
    data, addr = sock.recvfrom(1024) # buffer size is 1024 bytes
    if len(data) < 10:
        sync = True
        continue
    if not sync:
        continue
    write_frame(data)

