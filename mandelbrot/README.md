# Mandelbrot
Here I'll describe in some detail the design of the Mandelbrot program and its
main parts.

## Fixed point arithmetic
Before we proceed, we need to discuss how to represent decimal numbers in the
FPGA. I've chosen to use "fixed point binary two's complement", because that is
the easiest. Specifically, 2.16 bit representation is used, i.e. two bits for
the integer portion, and 16 bits for the fraction part.

This means we can represent real numbers in the range -2 .. 2, with an accuracy
of 0.5^16, i.e. about 5 decimal places of accuracy. A real number x is
represented using the binary number of x\*2^16, if x is positive, and
(x+4)\*2^16 if x is negative.

The first bit acts as a sign bit. It is '1' if the number of negative, and it
is '0' if the number is positive.

Some examples are:
```
-2        : 10.0000000000000000
-1.5      : 10.1000000000000000
-1        : 11.0000000000000000
-0.000015 : 11.1111111111111111
 0        : 00.0000000000000000
 0.000015 : 00.0000000000000001
 0.5      : 00.1000000000000000
 1        : 01.0000000000000000
 1.5      : 01.1000000000000000
```

## Multiplier
In this project we're using the built-in DSP to provide an 18-bit signed
multiplier.  This generates a 36-bit result in 4.32 bit representation.  The
actual multiplier is defined in a special Xilinx unimacro, but I've written a
testbench specifically for the multiplier (sim/mult\_tb.vhd).

The testbench is not selv-verifying, only investigative. This means one has to
manually examine the waveforms in order to determine, whether the multiplier
works as expected.  This is really just lazyness on my part and can easily be
fixed.

Anyway, the testbench currently performs the following multiplications:
```
-0.000015 * -0.000015 =  0.0000000002
-0.000015 *  0.000015 = -0.0000000002
 0.000015 *  0.000015 =  0.0000000002
 1.999985 *  1.999985 =  3.99994
-0.000015 *  1.999985 = -0.00003
```

The multiplier can be instantiated with a configurable number of clock cycles
of delay. I've chosen just a single clock cycle of delay for the time being.
This may have to be incremented when we start building the entire system. It's
very hard to predict what clcok frequencies the final design will be able to
run at.


## Iterator
This component performs the main calculation. It takes a input the complex
number c (or rather the real and imaginary values cx and cy).  It then iterates
the Mandelbrot function a number of times and stops when either the maximum
iteration count is reached, or an overflow occurs.

The testbench is again only investigative, and only tests a single starting
value: -1 + 0.5\*i.

The iterator has been heavily optimized to use only a single multiplier, and to
pipeline the calculations. Furthermore, the calculations have been rewritten to
use only two (real) multiplications:
```
new\_x = (x+y)\*(x-y) + cx
new\_y = 2*(x*y) + cy
```

Each iteration takes three clock cycles, and is controlled by a simple state machine.


## Priority encoder

