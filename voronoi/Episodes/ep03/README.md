# Episode 3 : Many points.

Welcome to this third episode of the tutorial. In this episode, we will add
many Voronoi points moving across the screen.

We need several instances of the move.vhd module, and the same number of
instances of the dist.vhd module. This is handled in lines 124-153 in
voronoi.vhd.

Additionally, we need to calculate the minimum distance.  This is done in a
simple process in lines 156-169.

Note that we are doing everything combinatorially. This could potentially
causing timing problems, but since the clock frequency is only 25 MHz, there is
a lot of time in each clock period. If we do run into problems, we should add a
register to the dist\_s signals.

## Future work
TBD.
