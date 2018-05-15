#! /usr/bin/env python

# This converts a binary file into a text file written in hexadecimal with each
# byte on a single line.
# This is used to initialize memory.
#
# Usage: ./bin2hex.py <source> <dest>

import sys

infilename = sys.argv[1]
outfilename = sys.argv[2]

result = []

a = open(infilename, "rb")
for c in a.read():
    h = format(ord(c), '08b')
    result.append(h)
a.close()

fl = open(outfilename, "w")
for i in result:
    fl.write(i+"\n")
fl.close()

