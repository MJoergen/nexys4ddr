# Episode 6 : Removing the strange visual rastering effect.

Welcome to this sixth episode of the tutorial. In this episode, we will remove
the visual rastering effect that sometimes occurs.

## Avoid rounding errors

After some debugging I found out that the rastering occurs because of rounding
errors in the RMS calculation. The boundary between two regions is determined
by equality of two distances, and any small rounding error in the distances
will distort this boundary.

So I changed the interface to the RMS module, so the output is in 10.3 fixed
point format. This gives three bits for the fractional part, and this is enough
to avoid any rounding errors in the approximate calculation I'm doing.  To be
clear, the approximation itself naturally introduces errors, but no further
errors are added subsequently. This was the case in the previous
implementation, where the distance was rounding to an integer.

So this change affects the files rms.vhd, dist.vhd, and voronoi.vhd.

## Other changes
As part of the debugging, I felt the need to stop, start, and reset the movement
of the Voronoi points. So I make use of two of the switches:
* Switch 0 is an on/off button for the movement
* Switch 1 is a reset.

This means changes to the move.vhd, voronoi.vhd, and voronoi.xdc files.

## Timing error
Furthermore, I found a mistake in the constraint file voronoi.xdc, which meant
that timing constraint was not applied correctly. When I fixed that, the timing
failed miserably. So I've had to add a register to the output of the dist.vhd
module, as well as split the comparison process p\_mindist into two sets of
comparisons.

## Current Statistics
Just for fun, I did some design analysis using Vivado and found the following results:
* Utilization of FPGA is around 12% of the available slices.
* Slack for the 25 MHz clock is around 11 ns (out of 40 ns).
* Slack for the 100 MHz clock is around 8 ns (out of 10 ns).

## Future work
* Implement a better approximation for the RMS module.  The current
  implementation uses a combination of two linear functions, but perhaps using
  three or four linear functions will give better results.
* Increase the resolution to 1280\*1024, using 108 MHz clock frequency. This
  requires rewriting the p\_mindist process.
