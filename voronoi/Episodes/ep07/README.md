# Episode 7 : Making the circles more round.

Welcome to this seventh episode of the tutorial. In this episode, we will
improve the RMS calculation to make the circles more round.

So instead of just considering the maxium of two or three lines, I've increased
the number of lines to seven. Furthermore, I've increased the resolution to
seven fractional bits.

The idea is to approximate a circle by a number of lines. For the unit circle
the lines in question are each given by ax+by=1, where the coefficients a and b
satisfy a^2+b^2=1.

## Future work
* Increase the resolution to 1280\*1024, using 108 MHz clock frequency. This
  requires rewriting the p\_mindist process.
