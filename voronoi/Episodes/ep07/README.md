# Episode 7 : Making the circles more round.

Welcome to this seventh episode of the tutorial. In this episode, we will
improve the RMS calculation, so the circles around each Voronoi point become
more round.

## A better approximation

The RMS module calculates sqrt(x^2+y^2). Geometrically, the points with a
given RMS value form a circle, and in Episode 6 this circle was approximated by
just two straight lines (per 45 degrees). This gives an error of up to 3%,
which is visible as slightly "square" circles.

A line ax+by=1 with a^2+b^2=1 touches the unit circle. So if we take a handful
of such tangent lines at different angles, and choose the *maximum* of a\*x+b\*y
over all lines, we get a polygon that hugs the circle closely. The more lines,
the better the approximation.

In this episode I use seven lines, covering the angles from 0 to 45 degrees.
The remaining angles are handled by swapping x and y, exactly as before. To
avoid real numbers, a and b are scaled by 128, i.e. a^2+b^2=128^2.

The values of b are chosen as 128-j^2, and then a=round(sqrt(128^2-b^2)). This
gives almost equidistant angles, as shown in the table below, where
angle=atan(a/b):

| j |  a |  b  | angle | diff |
|--:|---:|----:|------:|-----:|
| 0 |  0 | 128 |  0.0  |      |
| 1 | 16 | 127 |  7.2  |  7.2 |
| 2 | 32 | 124 | 14.5  |  7.3 |
| 3 | 47 | 119 | 21.6  |  7.1 |
| 4 | 62 | 112 | 29.0  |  7.4 |
| 5 | 76 | 103 | 36.4  |  7.4 |
| 6 | 89 |  92 | 44.1  |  7.7 |

The worst case is halfway between two lines, where the error is
1-cos(7.7/2 degrees), i.e. about 0.2%. The testbench [rms\_tb.vhd](rms_tb.vhd)
sweeps over all (x,y) on the screen, and confirms a maximum error of 0.23%,
compared to 3.0% in Episode 6. Run it with `make sim` (requires GHDL).

This change is in rms.vhd.

## More fractional bits

Episode 6 taught us to avoid rounding errors in the distance. Since a and b are
now scaled by 128, the value a\*x+b\*y is exactly 128 times the distance. So
instead of dividing by 128, I simply interpret the result as having seven
fractional bits, i.e. 10.7 fixed point instead of 10.3.

To avoid hardcoding the bit widths, the number of fractional bits is now a
constant C\_RESOLUTION in voronoi.vhd, passed down as the generic G\_RESOLUTION
to dist.vhd and rms.vhd. The brightness calculation in voronoi.vhd uses the
same integer bits of the distance as before, just shifted by C\_RESOLUTION.

## Future work
* Increase the resolution to 1280\*1024, using 108 MHz clock frequency. This
  requires rewriting the p\_mindist process.
