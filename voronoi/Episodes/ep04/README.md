# Episode 4 : Colour scheme

Welcome to this fourth episode of the tutorial. In this episode, we will
improve the colour scheme.

First of all, I noticed that the Nexys4DDR board I'm using supports 12-bit
colours rather than just 8-bit colours I used so far. So this is fixed
by adding the missing pin locations to the voronoi.xdc constraint file and
updating the top level port declaration in voronoi.vhd (line 17).

I've decided to give each Voronoi center its own colour, and this is done in the
p\_mindist process in lines 128-149 of voronoi.vhd.

The pixel colour generation is now made up of a 4-bit brightness and a 3-bit hue.
This takes place in lines 160-170 of voronoi.vhd.

## Future work
Improve the movement of the Voronoi points.
