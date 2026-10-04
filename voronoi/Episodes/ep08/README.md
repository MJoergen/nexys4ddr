# Episode 8 : Increasing the resolution

Welcome to this eighth episode of the tutorial. In this episode, we will
increase the screen resolution from 640x480 to 1280x1024. The picture is the
same as in Episode 7, just with four times as many pixels.

Four times as many pixels in the same 1/60 second means a pixel clock of 108
MHz instead of 25 MHz. Generating this clock is easy. Making the design keep
up with it is where most of the work is.

## A new clock

So far, the VGA clock was made by dividing the 100 MHz input clock by 4. But
108 MHz can not be made by dividing 100 MHz. Instead, I use an MMCM, which is
a PLL inside the FPGA. It first multiplies the input up to a high frequency
(the VCO), and then divides it down again: 100 MHz \* 54 / 5 = 1080 MHz, and
1080 MHz / 10 = 108 MHz.

This is the new file clk.vhd. The clock divider in voronoi.vhd is gone, and so
is the create\_generated\_clock constraint in voronoi.xdc, because Vivado
derives the MMCM output clock automatically.

## New VGA timing

The VGA controller in vga.vhd gets new constants, taken from the VESA
standard:

|                  | 640x480 | 1280x1024 |
|------------------|--------:|----------:|
| Pixel clock      |  25 MHz |   108 MHz |
| Horizontal total |     800 |      1688 |
| HS start         |     656 |      1328 |
| HS time          |      96 |       112 |
| Vertical total   |     525 |      1066 |
| VS start         |     490 |      1025 |
| VS time          |       2 |         3 |

## Wider coordinates

The coordinates now go up to 1687, so they need 11 bits instead of 10. This
changes G\_SIZE from 10 to 11 in voronoi.vhd, and a lot of "9 downto 0" into
"10 downto 0". The output ports of move.vhd were hardcoded to 10 bits, so they
now use G\_SIZE instead. The screen size itself appears in three files:
voronoi.vhd, vga.vhd, and move.vhd.

Two small adjustments keep the picture looking the same:
* The start position uses i\*46 instead of i\*23, so the points spread over
  the whole (twice as wide) screen.
* All distances are now twice as many pixels, so the brightness uses the
  distance bits one position higher.

## Pipelining

At 25 MHz each pixel had 40 ns to pass through: sort, subtract, sort,
multiply, find the maximum of seven lines, and then find the minimum of 32
distances. At 108 MHz there are only 9.3 ns, which is far too little.

The solution is pipelining: split the calculation into small steps with a
register after each step. A new pixel still enters every clock cycle, but each
pixel now takes several clock cycles to get through.

* dist.vhd: A register after the subtraction.
* rms.vhd: Registers after the sorting, after the multiplications (which lets
  Vivado place them inside the DSPs), and after comparing the lines in pairs.
  The last four values are compared as a tree, i.e. only two comparisons in
  series.
* p\_mindist in voronoi.vhd: Episode 6 split the 32 comparisons into two
  chains of 16. Now they form a binary tree: 32, 16, 8, 4, 2, 1, with a
  register after each level, so only one comparison per clock cycle.

In total, the colour of a pixel is ready 10 clock cycles after its
coordinates: 4 in dist.vhd and 6 in p\_mindist. Therefore the new process
p\_delay delays the pixel coordinates and the synchronization signals by
C\_LATENCY = 10 clock cycles. Without this, the picture would be shifted 10
pixels to the right.

## Testbench

The rms module now needs a clock, so the testbench [rms\_tb.vhd](rms_tb.vhd)
must take the pipeline into account: it applies a new value in every clock
cycle, and compares the output with the value applied 2 clock cycles earlier.
It sweeps the whole 1280x1024 screen, so `make sim` takes a few minutes. The
maximum error is still 0.23%.

## Future work
* The points move the same number of pixels per frame as before, so on the
  bigger screen they appear to move half as fast. Make them move faster.
