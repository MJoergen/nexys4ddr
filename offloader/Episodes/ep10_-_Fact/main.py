#!/usr/bin/env python
import socket
import math

# Open a UDP socket
sock = socket.socket(socket.AF_INET,    # Internet
                     socket.SOCK_DGRAM) # UDP

# IP address and port number of the FPGA device
DUT = ("192.168.1.77", 4660)

NUM_BYTES   = 9
NUM_FACTORS = 30
NUM_PRIMES  = 4

def enc(x, num_bytes):
   # Convert the number to a hex string. Remove the preceding "0x" and the trailing optional "L".
   str_x = hex(x)[2:].split('L')[0]
   # Prepend string with 0's.
   str_x = "0"*(2*num_bytes-len(str_x)) + str_x
   return str_x.decode("hex")

def dec(s, num_bytes):
   return s[2*num_bytes:], int(s.encode('hex')[0:2*num_bytes], 16)

def offloader(num):
   print "The number is:", num

   # Generate message
   message  = enc(num,     2*NUM_BYTES)
   message += enc(factors, NUM_FACTORS)
   message += enc(primes,  NUM_PRIMES)

   #print "Sending message: ",message.encode('hex')
   sock.sendto(message, DUT)

   while True:
      data, server = sock.recvfrom(1500)
      #print "Received message:",data.encode('hex')

      # Decode message received from offloader
      data, x             = dec(data, 2*NUM_BYTES)
      data, y             = dec(data,   NUM_BYTES)
      data, mon_cf        = dec(data, 4)
      data, mon_miss_cf   = dec(data, 4)
      data, mon_miss_fact = dec(data, 4)
      data, mon_factored  = dec(data, 4)
      data, mon_clkcnt    = dec(data, 2)
      print x,y,mon_cf,mon_miss_cf,mon_miss_fact,mon_factored,mon_clkcnt

#offloader(7*(2**128+1))
offloader(1879048199)

