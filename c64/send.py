#!/usr/bin/env python

import socket
import argparse
import dnet

parser = argparse.ArgumentParser(description='Process some integers.')
parser.add_argument('--filename', default='rom.bin')
parser.add_argument('--address',  default='0xF000')
parser.add_argument('--mac',      default='F4:6D:04:11:22:33')
parser.add_argument('--ip',       default='192.168.1.46')
parser.add_argument('--port',     default='9029')
parser.add_argument('--reset',    default=3)
args = parser.parse_args()

print "Using the following parameters:"
print "filename :", args.filename
print "address  :", args.address
print "mac      :", args.mac
print "ip       :", args.ip
print "port     :", args.port
print "reset    :", args.reset

# Setup ARP (this requires root privilege)
arp = dnet.arp()
pa = dnet.addr(args.ip)
ha = dnet.addr(args.mac)
arp.add(pa, ha)

input_file = open(args.filename, "rb")
data = input_file.read()
input_file.close()

print "file length =", len(data)

assert len(data) == 4096

addr_lo = int(args.address, 16) & 0xFF
addr_hi = int(args.address, 16) / 256

print addr_lo
print addr_hi

message0 = chr(addr_lo) + chr(addr_hi) + chr(3) + data[0:1024]
message1 = chr(addr_lo) + chr(addr_hi + 4) + chr(3) + data[1024:2048]
message2 = chr(addr_lo) + chr(addr_hi + 8) + chr(3) + data[2048:3072]
message3 = chr(addr_lo) + chr(addr_hi + 12) + chr(1) + data[3072:4096]

sock = socket.socket(socket.AF_INET, # Internet
                   socket.SOCK_DGRAM) # UDP
sock.sendto(message0, (args.ip, int(args.port)))
sock.sendto(message1, (args.ip, int(args.port)))
sock.sendto(message2, (args.ip, int(args.port)))
sock.sendto(message3, (args.ip, int(args.port)))

