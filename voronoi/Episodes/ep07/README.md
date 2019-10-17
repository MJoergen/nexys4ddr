# Episode 7 : Making the circles more round.

Welcome to this seventh episode of the tutorial. In this episode, we will
improve the RMS calculation to make the circles more round.

So instead of just considering the maxium of two or three lines, I've increased
the number of lines to seven. Furthermore, I've increased the resolution to
seven fractional bits.

The idea is to approximate a circle by a number of lines. For the unit circle
the lines in question are each given by ax+by=1, where the coefficients a and b
satisfy a^2+b^2=1.

With seven fractional bits, this corresponds to scaling the values of a and b
by a factor of 128, i.e. we get:
a^2+b^2=128^2.

The values for b are chosen as 128-j^2, where j is a non-negative integer. The
value of a is then selected such as a=round(sqrt(128^2-b^2)).

Choosing the b-values in that way leads to approximately equidistant slopes (or
rather angles), see the following table, where slope=a/b and angle=atan(slope):

 j |  a |  b  | slope | angle | diff
---+----+-----+-------+-------+-----
 0 |  0 | 128 | 0.000 |  0.0  |
 1 | 16 | 127 | 0.126 |  7.2  |  7.2
 2 | 32 | 124 | 0.258 | 14.5  |  7.3
 3 | 47 | 119 | 0.395 | 21.6  |  7.1
 4 | 62 | 112 | 0.554 | 29.0  |  7.4
 5 | 76 | 103 | 0.738 | 36.4  |  7.4
 6 | 89 |  92 | 0.967 | 44.1  |  7.7

In other words, the average angular difference between the lines is 7.35
degrees, and the actual differences vary only very little around this average.

## Future work
* Increase the resolution to 1280\*1024, using 108 MHz clock frequency. This
  requires rewriting the p\_mindist process.
