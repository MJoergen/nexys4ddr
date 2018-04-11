#!/usr/bin/env python

import socket

UDP_IP = "192.168.1.46"
UDP_PORT = 9029
MESSAGE = chr(80) + chr(128) + chr(0) + "Hvad skal jeg nu skrive ????"

sock = socket.socket(socket.AF_INET, # Internet
                   socket.SOCK_DGRAM) # UDP
sock.sendto(MESSAGE, (UDP_IP, UDP_PORT))
