#!/usr/bin/env python
import socket
import pprint
import datetime
import atexit

# This file receives the compressed line data
# and writes .ppm files with each frame.

UDP_IP = "192.168.1.43"
UDP_PORT = 4660 

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))


def write_frame(frm_num, data):
    file_name = "frame_{:05d}.bin".format(frm_num)
    output_file = open(file_name, "wb")
    #assert (len(data) % 2) == 0
    #vals = []
    #for i in range(len(data)/2):
    #    vals += [data[i*2+1]]*(1+ord(data[i*2]))
    #assert len(vals) == 8*640
    #output_file.write("".join(vals))
    output_file.write("".join(data))
    output_file.close()

max_len = 0
min_len = 10000
sync = False
cnt = 0
frm_num = 0
now = datetime.datetime.now()

@atexit.register
def goodbye():
    print "min_len=" + str(min_len)
    print "max_len=" + str(max_len)

while True:
    cnt += 1
    data = sock.recv(2048) # buffer size is 2048 bytes
    #now = datetime.datetime.now()
    #print "Frame:{:d} at {:s}, len={:d}".format(frm_num, str(now), len(data))
    if len(data) < min_len:
        min_len = len(data)
    if len(data) > max_len:
        max_len = len(data)
    #    if len(data) < 10:
    #        # This is a syncronization frame.
    #        # Indicates end (or start) of a new frame.
    #        if sync == True:
    #            break
    #        sync = True
    #        continue
    #    if not sync:
    #        continue
    write_frame(frm_num, data)
    frm_num += 1

