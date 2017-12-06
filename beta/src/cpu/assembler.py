#! /usr/bin/env python

import sys
import time

filename = sys.argv[1]

def main():
   a = prepare_file(filename)
   result = translate(a)
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
def to_b(a, l=16):
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
        "ADD",
        "SUB",
        "MUL",
        "Reserved"
        "CMPEQ",
        "CMPLT",
        "CMPLE",
        "Reserved"

        "AND",
        "OR",
        "XOR",
        "Reserved"
        "SHL",
        "SHR",
        "SRA",
        "Reserved"]



def translate(a):
    print (a)
    f = []
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


