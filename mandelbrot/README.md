# Mandelbrot
Here I'll describe in some detail the design of the Mandelbrot program and its
main parts.

## Fixed point arithmetic
Before we proceed, we need to discuess how to represent decimal numbers in the
FPGA. I've chosen to use "fixed point binary two's complement", because that is
the easiest. Specifically, 2.16 bit representation is used, i.e. two bits for
the integer portion, and 16 bits for the fraction part.

This means we can represent real numbers in the range -2 .. 2, with an accuracy
of 0.5^16, i.e. about 5 decimal places of accuracy. A real number x is
represented using the binary number of x\*2^16, if x is positive, and
(x+4)\*2^16 if x is negative.

Some examples are:
* -2        : 10.0000000000000000
* -1        : 11.0000000000000000
*  0        : 00.0000000000000000
*  1        : 01.0000000000000000
*  0.5      : 00.1000000000000000
* -1.5      : 10.1000000000000000
*  0.000015 : 00.0000000000000001

## Multiplier
In this project we're using the built-in DSP to provide an 18-bit signed multiplier.
This generates a 36-bit result in 4.32 bit representation.

## Iterator

## Priority encoder

