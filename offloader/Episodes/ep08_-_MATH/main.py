#!/usr/bin/env python
import socket
import sys

def python_gcd(num1, num2):
    if (num2==0):
        return num1
    else:
        return python_gcd(num2, num1%num2)

# Open a UDP socket
sock = socket.socket(socket.AF_INET,    # Internet
                     socket.SOCK_DGRAM) # UDP

# IP address and port number of the FPGA device
DUT = ("192.168.1.77", 4660)

def offloader(cmd, num1, num2):
    # Convert the numbers to a hex string. Remove the preceding "0x" and the trailing optional "L".
    str1 = hex(num1)[2:].split('L')[0]
    str2 = hex(num2)[2:].split('L')[0]

    # Prepend string with 0's.
    str1 = "0"*(16-len(str1)) + str1
    str2 = "0"*(16-len(str2)) + str2

    # Prepare message to send to offloader
    message = cmd.decode("hex") + str1.decode("hex") + str2.decode("hex")

    #print "Sending message: ",message.encode('hex')
    sock.sendto(message, DUT)
    data, server = sock.recvfrom(1500)
    #print "Received message:",data.encode('hex')

    # Decode message received from offloader
    s = data.encode('hex')[0:16]
    return int(s,16)

# Test GCD module
num1 = 12345678901234567890
num2 =  9876543210987654321

print "The two numbers are:", num1, "and", num2
print "GCD calculated by offloader:", offloader("0102", num1, num2)
print "GCD calculated by python:   ", python_gcd(num1, num2)

num1 = 123456789
num2 = 987654321

print "The two numbers are:", num1, "and", num2
print "MULT calculated by offloader:", offloader("0101", num1, num2)
print "MULT calculated by python:   ", num1*num2

