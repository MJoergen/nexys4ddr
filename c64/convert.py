#! /usr/bin/env python

import sys
import time
import string

filename = sys.argv[1]

def main():
    a = open(filename, "rb").read()
    result = translate(a)
    print result
    write_file(result)

#pads binary translation with addition 0's
def to_b(a, l=32):
    num = to_binary(a)
    length = len(num)
    diff = l - length
    rest = [ "0" for i in range(diff) ]
    rest = "".join(rest)
    return rest + num

#attempts to convert to binary
to_binary = lambda x: x >= 0 and str(bin(x))[2:] or "-" + str(bin(x))[3:]


def getval(s):
    return int(s, 16)

def translate(a):
    f = []
    for c in a:
        v = ord(c)
        print hex(v)
        b = to_b(v)
        f.append(b)
    return f

def write_file(f):
    name = filename + ".txt"
    fl = open(name, "w")
    for i in f:
        fl.write(i+"\n")
    fl.close()

if __name__ == "__main__":
    t0 = time.time()
    main()
    print (time.time() - t0)


