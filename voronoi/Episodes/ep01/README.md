# Episode 1 : Hello world.

Welcome to this first episode of the tutorial. In this episode, we will focus
on getting a simple static image to the screen, showing the basics of a Voronoi
diagram. There will be just a single Voronoi point.

The design consist of a VGA controller that generates the synchronization
signals needed by the VGA monitor as well as current pixel coordinates.

These pixel coordinates are connected to a combinatorial circuit that calculates
the euclidean distance between the current pixel and the Voronoi center.

## Calculating euclidean distance.
The euclidean distance is calculated by the block dist.vhd, which takes as 
input the coordinates of the two points, and outputs a distance.

First the horizontal and vertical displacements are calculated. This is done
by subtracting the smallest x-coordinate from the largest x-coordinate, and
similarly in the y-direction. This "sorting-before-subtracting" avoids having
to deal with negative numbers and signed arithmetic.

Secondly the RMS valus of the displacements are calculated, i.e. sqrt(x^2+y^2).
Initially, I've chosen a very crude approximation, where first the coordinates
are sorted such that 0\<x\<y. Then the RMS value is approximately equal:
* y, when x is less than y/2
* x+y/2, when x is greater than y/2.

This is indeed a very crude approximation, and the greatest absolute error is
at x=y/2, where the error is 12% of y.

## Generating the Voronoi diagram.
In this initial episode, only a single Voronoi point is used, and it is stationary.
The distance between the current pixel and the Voronoi point is calculated
in lines 77-92 in voronoi.vhd by instantiating the dist.vhd module.

The lowest eight bits of the distance are directly mapped to the colour output.
This leads to weird colour effects, and will be changed in a future episode.

## Future work
Looking at the generated picture on the VGA monitor, the "rings" are not even convex.
This is an artifact of our very crude approximation to the euclidean distance, and
will be fixed in the next episode. There we will allow the Voronoi point to move about,
and we'll generate a better colour scheme.

