#!/usr/bin/env python
import socket
import math

# Open a UDP socket
sock = socket.socket(socket.AF_INET,    # Internet
                     socket.SOCK_DGRAM) # UDP

# IP address and port number of the FPGA device
DUT = ("192.168.1.77", 4660)

NUM_BYTES = 9

def enc(x, num_bytes):
   # Convert the number to a hex string. Remove the preceding "0x" and the trailing optional "L".
   str_x = hex(x)[2:].split('L')[0]
   # Prepend string with 0's.
   str_x = "0"*(2*num_bytes-len(str_x)) + str_x
   return str_x.decode("hex")

def dec(s, num_bytes):
   x = int(s.encode('hex')[0:4*num_bytes], 16)
   y = int(s.encode('hex')[4*num_bytes:6*num_bytes], 16)
   if y > 2**(NUM_BYTES*8-1):
       y -= 2**(NUM_BYTES*8)
   return x,y

def offloader(num):
   print "The number is:", num

   # Generate message
   message = enc(num, 2*NUM_BYTES)

   print "Sending message: ",message.encode('hex')
   sock.sendto(message, DUT)

   while True:
      data, server = sock.recvfrom(1500)
      #print "Received message:",data.encode('hex')

      # Decode message received from offloader
      x,y = dec(data, NUM_BYTES)
      print x,y

offloader(7*(2**128+1))

