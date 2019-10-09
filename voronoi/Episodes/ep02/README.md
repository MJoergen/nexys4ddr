# Episode 2 : Moving points.

Welcome to this second episode of the tutorial. In this episode, we will focus
on getting the Voronoi point to move about the screem and to improve the quality
of the image.

## Dealing with the non-convex "rings"
In the first episode, the "rings" were not even convex, and that is just not what
we wanted. The problem was our very crude approximation to the RMS, but just a small
change to the approximation gives much better results.

The approximation we now use is:
* y, when x is less than y/4
* x/2+7y/8, when x is greater than y/4.

This is a much better approximation and has a maximum absolute error of 4% of
y, when x=y.

## Better colour scheme
In the previous episode the colours were all mixed, because we paid no attention to the RGB nature of the colour signal.
In this episode I've made a list of 16 diffrent colours (in lines 56-75 of voronoi.vhd), and then
we use bits 7-4 to select the corresponding colour.

## Moving the Voronoi point around the screen.
The coordinates of the Voronoi point has been moved to a new module move.vhd, which
has the responsibility of moving the point when an input signal move\_i is asserted.

## Future work
In the next episode, we'll get several Voronoi points in use.

