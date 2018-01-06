#! /usr/bin/env python

import sys
import time

def main():
    result = translate()
    write_file(result)

def filter_line(a, op=","):
    idx = a.find(op)
    if idx == -1:
        return a
    elif idx == 0:
        return ''
    else:
        a = a[:idx]
    return a    

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

def translate():
    f = []
    for y in range(256):
        d = y / 13
        m = y % 13
        bd = to_b(d, 5)
        bm = to_b(m, 4)
        f.append(bd+bm)
    return f

def write_file(f):
    name = "divmod13.txt"
    fl = open(name, "w")
    for i in f:
        fl.write(i+"\n")
    fl.close()

if __name__ == "__main__":
    t0 = time.time()
    main()
    print (time.time() - t0)


