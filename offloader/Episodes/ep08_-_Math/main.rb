#!/usr/bin/env ruby

require 'socket'

def calc(cmd, num1, num2)

   # Encode byte string
   msg = cmd + "%016x" % num1 + "%016x" % num2
   msg = [msg].pack('H*')

   # Send request and wait for response
   socket = UDPSocket.new
   socket.send(msg, 0, "mjoergen.eu", 4660)
   msg,sender = socket.recvfrom(1500)
   socket.close

   # Decode byte string
   msg = msg.unpack('H*').first
   return msg[0..15].to_i(16)
end

num1 = 1234
num2 = 9876

mult = calc("0101", num1, num2)
gcd  = calc("0102", num1, num2)

print "%d*%d=%d\n" % [num1, num2, mult]
print "gcd(%d,%d)=%d\n" % [num1, num2, gcd]

