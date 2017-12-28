#! /usr/bin/env python

import sys
import time
import string

filename = sys.argv[1]

def main():
    a = prepare_file(filename)
    result = translate(a)
    print result
    write_file(result)

def filter_line(a, op="|"):
    idx = a.find(op)
    if idx == -1:
        return a
    elif idx == 0:
        return ''
    else:
        if op == "|":
            a = a[:(idx-1)]
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


def prepare_file(filename):
    f = open(filename)
    a = f.readlines()
    a = map(filter_line, a)                      # Remove comments
    a = [ i.strip() for i in [ x for x in a ] ]  # Remove white space
    a = filter(lambda x : x != '', a)            # Remove empty elements
    return a

mapping = [
    # 000xxx
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    # 001xxx
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    # 010xxx
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    # 011xxx
    "LD",
    "ST",
    "Reserved",
    "JMP",
    "Reserved",
    "BEQ",
    "BNE",
    "LDR",
    # 100xxx
    "ADD",
    "SUB",
    "MUL",
    "Reserved",
    "CMPEQ",
    "CMPLT",
    "CMPLE",
    "Reserved",
    # 101xxx
    "AND",
    "OR",
    "XOR",
    "Reserved",
    "SHL",
    "SHR",
    "SRA",
    "Reserved",
    # 110xxx
    "ADDC",
    "SUBC",
    "MUL",
    "Reserved",
    "CMPEQC",
    "CMPLTC",
    "CMPLEC",
    "Reserved",
    # 111xxx
    "ANDC",
    "ORC",
    "XORC",
    "Reserved",
    "SHLC",
    "SHRC",
    "SRAC",
    "Reserved"]


def getreg(s):
    assert s[0].upper() == 'R'
    return int(s[1:])

def getval(s):
    return int(s, 0)

def translate(a):
    f = []
    for c in a:
        cmd = c.replace('(',' ').replace(')',' ').replace(',',' ').split()
        print cmd
        assert len(cmd) == 4
        i = mapping.index(cmd[0])
        if i>=32 and i<48:
            ra = getreg(cmd[1])
            rb = getreg(cmd[2])
            rc = getreg(cmd[3])
            opc = to_b((i<<26) + (rc<<21) + (ra<<16) + (rb<<11))
        elif i==25:
            rc = getreg(cmd[1])
            vb = getval(cmd[2])
            ra = getreg(cmd[3])
            opc = to_b((i<<26) + (rc<<21) + (ra<<16) + vb)
        else:
            ra = getreg(cmd[1])
            vb = getval(cmd[2])
            rc = getreg(cmd[3])
            opc = to_b((i<<26) + (rc<<21) + (ra<<16) + (vb & 0xFFFF))
        f.append(opc)
    return f

def write_file(f):
    name = filter_line(filename, op=".")
    name = name + ".txt"
    fl = open(name, "w")
    for i in f:
        fl.write(i+"\n")
    fl.close()

if __name__ == "__main__":
    t0 = time.time()
    main()
    print (time.time() - t0)


