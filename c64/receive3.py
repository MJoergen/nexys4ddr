#!/usr/bin/env python
import socket
import atexit
import numpy

# This file receives the compressed line data
# and writes the re-assembled frames to individual files.

UDP_IP   = "192.168.1.43"
UDP_PORT = 4660 

sock = socket.socket(socket.AF_INET, # Internet
                     socket.SOCK_DGRAM) # UDP
sock.bind((UDP_IP, UDP_PORT))


cur_frm = 0    # Current frame. Should increment 60 times a second.
def write_frame(frame, err):
   global cur_frm
   if err:
      file_name = "frame_{:04d}_err.bin".format(cur_frm)
   else:
      file_name = "frame_{:04d}.bin".format(cur_frm)
   output_file = open(file_name, "wb")
   output_file.write("".join(frame))
   output_file.close()
   cur_frm += 1


# Initialize frame buffer
frame = [""]*480

last_line = 0  # Last received line number.
err = False    # Does current frame contain any errors?

# First byte is the VGA line number (divided by 8), i.e. a value in the range 0-59.
# Remaining 5120 bytes are 8 lines of 640 bytes.
def process_data(data):
   global last_line
   global err
   global frame
   lin_num = ord(data[0])
   assert (lin_num >= 0) and (lin_num <= 59)

   if lin_num < last_line:
      # New frame started.
      write_frame(frame, err)
      err = False

   if lin_num != (last_line+1)%60:
      err = True

   last_line = lin_num

   # Store received data in frame buffer
   for i in range(8):
      frame[lin_num*8+i] = "".join(data[1+i*640:1+(i+1)*640])


# Array of received packet lengths
lens = []

@atexit.register
def goodbye():
   global lens
   a = numpy.array(lens)
   print "Statistics of received packet lengths:"
   print "minimum: " + str(numpy.amin(a))
   print "maximum: " + str(numpy.amax(a))
   print "median:  " + str(numpy.median(a))
   print "mean:    " + str(numpy.mean(a))
   print "std.dev: " + str(numpy.std(a))

def decompress(data):
   assert (len(data) % 2) == 0
   vals = []
   for i in range(len(data)/2):
       vals += [data[i*2+1]]*(1+ord(data[i*2]))
   assert len(vals) == (8*640 + 1)
   return vals

# Process incoming packets.
# Expected bandwidth is 3600 packets pr. second.
while True:
   data = sock.recv(4096)  # same buffer size as fifo in FPGA.
   lens += [len(data)]
   process_data(decompress(data))

