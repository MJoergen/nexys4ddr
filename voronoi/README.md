# Voronoi diagram on FPGA

This project will be a tutorial on how to make beautiful Voronoi diagrams on an FPGA.

The idea of this tutorial is to show the work in progress, i.e. how do you
start on such a project, what steps do you take, etc.  The strategy is to - at
every step, i.e. every episode - have a working project, albeit with limited
functionality.

So already in the very first episode we have a project that synthesizes to a
bitfile that runs on the FPGA and generates an output.

Once the very first working project is made, every subsequent episode consists
of small incremental steps, each almost imperceptible. The important thing is
that each new episode brings *some* new functionality that is directly
testable.

[**Episode 1**](Episodes/ep01) : Hello World! This will go through the basics
of generating a simple and crude Voronoi image.

[**Episode 2**](Episodes/ep02) : The Voronoi point is now moving about, and the
image quality is greatly enhanced.

[**Episode 3**](Episodes/ep03) : Several Voronoi points are now in use.

[**Episode 4**](Episodes/ep04) : Improving colour scheme.

[**Episode 5**](Episodes/ep05) : Improving movement of Voronoi points.

[**Episode 6**](Episodes/ep06) : Removing strange visual rastering effect.

[**Episode 7**](Episodes/ep07) : Making the circles more round.

[**Episode 8**](Episodes/ep08) : Increasing the resolution.
