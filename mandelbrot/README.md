# Mandelbrot
This draws the [Mandelbrot set](https://en.wikipedia.org/wiki/Mandelbrot_set)
in VHDL on the Nexys 4 DDR board, which has a Xilinx Artix-7 XC7A100T FPGA. The
picture (640x480) is shown on the VGA output, and you can pan and zoom using the
buttons on the board. The same design also runs on the
[MEGA65](https://mega65.org/) (board revision R6), which has a Xilinx Artix-7
XC7A200T FPGA, see [MEGA65](#mega65).

All 240 DSPs of the FPGA are used in parallel for the calculation, and the
picture is stored in block RAM. Generating a complete picture takes about 1.84 ms
(estimated by the model), with the main clock at 188.24 MHz. On the MEGA65 it
takes about 0.86 ms.

## The algorithm
For each pixel, which corresponds to a complex number $c$, we iterate
$z \mapsto z^2 + c$ starting from $z = 0$, and count the number of iterations
until the real or the imaginary part of $z$ leaves the range -2 to 2 (the range
of the number format), up to a maximum of 511. This count decides the colour
of the pixel, using one of four colour palettes, selected with switches 0 and 1
(see [Controls](#controls)). The points in the set (count 511) have their own
colour, and the other counts use the lower 8 bits of the count.

The numbers are 18-bit
[fixed point](https://en.wikipedia.org/wiki/Fixed-point_arithmetic) (2 integer
bits and 16 fractional bits), and each iteration needs only two real
multiplications, using the identity $x^2 - y^2 = (x+y)(x-y)$. Each of the 240
column modules contains an iterator with a single DSP multiplier, and the
iterator calculates one iteration every three clock cycles. Most points in the
set are found long before the maximum count, because the values of $z$ start
to repeat exactly (periodicity detection). The picture is divided into jobs,
each of 120 rows of a picture column, and the dispatcher gives the next job to
a column module as soon as it is idle.

[ALGORITHM.md](ALGORITHM.md) explains the design in detail: the number format,
the multiplier, the iterator (including how overflow is detected), the columns,
the dispatcher, and the timing and resource usage.

## Implementation results
The design is built with Vivado 2025.1, and meets timing at the 188.24 MHz main
clock on both boards. The resources used are:

| Resource    | Nexys 4 DDR (XC7A100T-1) | Available | MEGA65 R6 (XC7A200T-2) | Available
| ----------- | ------------------------ | --------- | ---------------------- | ---------
| DSP48E1     | 240                      | 240       | 450                    | 740
| Block RAM   | 128 RAMB36 + 2 RAMB18    | 135 RAMB36 | 128 RAMB36 + 2 RAMB18 | 365 RAMB36
| Slices      | 14,723                   | 15,850    | 30,114                 | 33,650
| LUTs        | 42,252                   | 63,400    | 81,630                 | 134,600
| Registers   | 45,018                   | 126,800   | 93,491                 | 269,200
| Setup slack | +0.092 ns                |           | +0.136 ns              |
| Hold slack  | +0.014 ns                |           | +0.053 ns              |

See [Resources and timing closure](ALGORITHM.md#resources-and-timing-closure)
for details.

## Files
The files used only in the MAIN clock domain are in [`src/main/`](src/main),
and those used only in the VGA clock domain are in [`src/vga/`](src/vga). The
files that are in both clock domains are in [`src/`](src).

| File             | Description
| ---------------- | -----------
| [`src/mandelbrot.vhd`](src/mandelbrot.vhd) | Top level. The ports are mapped directly to pins on the FPGA. Instantiates the clock and reset generation, the display memory, and the two modules below, and moves the frame rate from the MAIN clock domain to the VGA clock domain.
| [`src/mega65_r6.vhd`](src/mega65_r6.vhd) | Top level for the MEGA65 R6. The same as `mandelbrot.vhd`, but with the ports of the MEGA65.
| [`src/main/main.vhd`](src/main/main.vhd) | Everything in the MAIN clock domain: view control from buttons and switches, the dispatcher, and the frame rate (shown on the 7-segment display and on the VGA output).
| [`src/main/view.vhd`](src/main/view.vhd) | View control. Pans and zooms the view, and keeps it inside the range of the number format.
| [`src/main/fps.vhd`](src/main/fps.vhd), [`src/main/seg.vhd`](src/main/seg.vhd) | Frame rate. `fps` divides the clock frequency by the time taken by a picture and converts the result to decimal, and `seg` multiplexes the digits on the 7-segment display.
| [`src/vga/vga.vhd`](src/vga/vga.vhd) | Everything in the VGA clock domain: pixel counters, VGA output, and the frame rate overlay.
| [`src/main/iterator.vhd`](src/main/iterator.vhd) | Iterates the Mandelbrot function for a single point, using one DSP.
| [`src/main/column.vhd`](src/main/column.vhd) | A column module. Calculates one job (120 rows of a picture column) at a time, using one iterator.
| [`src/main/dispatcher.vhd`](src/main/dispatcher.vhd) | Controls the calculation of the entire picture: hands out the jobs to the idle column modules, and collects the results. Instantiates the column modules.
| [`src/main/scheduler.vhd`](src/main/scheduler.vhd) | Round-robin scheduler. Used by the dispatcher to give jobs to idle column modules.
| [`src/main/res_scheduler.vhd`](src/main/res_scheduler.vhd) | Scheduler for the results. Used by the dispatcher to pick which column module's result to accept, from the column modules that have a result ready.
| [`src/disp_mem.vhd`](src/disp_mem.vhd) | Display memory, holding the picture, in 128 blocks.
| [`src/vga/pix.vhd`](src/vga/pix.vhd), [`src/vga/disp.vhd`](src/vga/disp.vhd) | VGA output. `pix` generates the pixel counters, and `disp` generates the sync signals and the pixel colour.
| [`src/vga/palette_pkg.vhd`](src/vga/palette_pkg.vhd) | The four colour palettes, which convert the count of a pixel to its colour.
| [`src/vga/overlay.vhd`](src/vga/overlay.vhd), [`src/vga/font_pkg.vhd`](src/vga/font_pkg.vhd) | Frame rate overlay. `overlay` shows the frame rate in the top right corner of the picture, with the digits of the font in `font_pkg`.
| [`font/`](font) | The script that generates `font_pkg.vhd` from the [Spleen](https://github.com/fcambus/spleen) 16x32 font, and the license of the font (BSD 2-Clause, see [`font/LICENSE.spleen`](font/LICENSE.spleen)).
| [`src/clk_rst.vhd`](src/clk_rst.vhd) | Clock and reset generation: 188.24 MHz for the calculation and 25 MHz for VGA, each with a synchronous reset.
| [`sim/`](sim) | Testbenches and [GTKWave](https://github.com/gtkwave/gtkwave) setups, a Python model of the iterator count (`iterator_model.py`), a vectorized model of the complete picture (`model.py`), the same bit-accurate model in VHDL (`iterator_model_pkg.vhd`, used by the testbenches), and a script (`cmp_rtl.py`) that compares the output of the testbench `main_tb` with this model.
| [`nexys4ddr.xdc`](nexys4ddr.xdc), [`mega65-r6.xdc`](mega65-r6.xdc), [`mandelbrot.tcl`](mandelbrot.tcl) | Pin and timing constraints for each board, and script for synthesis and implementation with Vivado (including the optimization directives needed to meet timing), see `make nexys4ddr`. The script gets the FPGA part, the top level and the list of source files from the Makefile, so it must be run through `make nexys4ddr` or `make mega65-r6`.
| [`mandelbrot.xlsx`](mandelbrot.xlsx) | Spreadsheet used during the design. It iterates the example point -1+0.5i from [the iterator section](ALGORITHM.md#iterator) using real numbers.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm and the design.

## Controls
The picture is recalculated continuously: as soon as one picture is finished,
the next one is started. The view is controlled with the buttons and switches on
the board. The switch numbers are the bit numbers of the switch input, i.e.
`SW0` to `SW7` on the board.

| Control | Description
| ------- | -----------
| `BTNL`, `BTNR`, `BTNU`, `BTND` | Pan the picture left, right, up and down, by one pixel for each update. Panning stops at the edge of the number range (-2 to 2).
| `BTNC` | Zoom in. With switch 2 on, zoom out instead. The centre of the picture stays fixed, except when zooming out would move an edge of the view beyond -2 or 2; then the view is moved instead. Zooming stops at the smallest pixel size (2^-16), and when the view can not get larger.
| Switches 0 and 1 | Select the colour palette (switch 1 is the high bit). 0 (both off): the lower 8 bits of the count are the colour (RRRGGGBB), mostly blue and green, and the set is white. 1: rainbow, the hue goes around the colour circle every 16 counts. 2: fire, black, red, orange, yellow and white, with the square root of the count. 3: blue, white, orange and dark brown, with the logarithm of the count. In the palettes 1 to 3 the set is black.
| Switches 3 to 7 | Not used.
| `CPU RESET` | Resets the design and returns to the initial view.

While a button is held down, the view is updated about 22 times per second. Each
update pans by one pixel, or changes the size of a pixel by about 1.6%
(roughly 40% per second). The initial view shows the real axis from -1.67 to 1
and the imaginary axis from -1 to 1. See
[The top level](ALGORITHM.md#the-top-level) for details.

The 7-segment display shows the frame rate, i.e. the number of pictures
calculated per second, rounded down to an integer. It is calculated from the
time taken by the most recently finished picture, and updated after every
picture. The same frame rate is also shown in the top right corner of the VGA
output, in white on black.

### MEGA65
The MEGA65 has no buttons, switches or 7-segment display, so the view is
controlled with a joystick in each port, see
[`src/mega65_r6.vhd`](src/mega65_r6.vhd). The VGA output is on the VGA
connector.

| Control | Description
| ------- | -----------
| Joystick port 1: left, right, up, down | Pan the picture, like `BTNL`, `BTNR`, `BTNU` and `BTND`.
| Joystick port 1: fire | Zoom in, like `BTNC`.
| Joystick port 2: fire | Zoom out, like `BTNC` with switch 2 on.
| Reset button | Resets the design and returns to the initial view.

The colour palette is always palette 0, and the frame rate is only shown on the
VGA output.
The XC7A200T is larger, so the design uses 450 column modules (DSPs) instead
of 240, and writes four pixels (consecutive rows of a picture column) to the
display memory at a time instead of one, see
[`src/mega65_r6.vhd`](src/mega65_r6.vhd). The display memory takes one write
per clock cycle, so with one pixel in each write more column modules would
make the picture only slightly faster (about 1.80 ms instead of 1.84 ms). With
four pixels in each write the picture takes about 0.86 ms (estimated by the
model), see [MEGA65 R6](ALGORITHM.md#mega65-r6).

## Running
Type `make` to list the supported targets. The most important ones are:
* `make nexys4ddr` synthesizes and implements the design using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html),
  and generates `nexys4ddr.bit`. It expects Vivado in
  `/opt/Xilinx/2025.1/Vivado` (the variable `XILINX_DIR`). It takes about 6.5
  minutes, and writes the log to `vivado.log`.
* `make mega65-r6` does the same for the MEGA65 R6, and generates
  `mega65-r6.bit`.
* `make fpga` programs the Nexys 4 DDR board with `nexys4ddr.bit`, using `djtgcfg` from
  Digilent Adept.
* `make sim` runs all the testbenches one after another, without opening the
  waveform viewer, see [below](#simulation). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 2 minutes.
* `make run TB=iterator` runs a single testbench and writes the waveform to
  `sim/iterator.ghw`. Without `TB` it lists the available testbenches. It has
  the same requirements as `make sim`.
* `make check TB=iterator` does the same as `make run`, and then shows the
  waveform in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

## Simulation
There are testbenches in [`sim/`](sim) for `dispatcher`, `column`, `iterator`,
`scheduler`, `res_scheduler`, `view`, `vga`, `overlay`, `disp_mem` and `fps`.
All of them are self-checking, and stop with an error if the result is wrong.
They stop by themselves when they are finished.

There is also a testbench for `main`, which is not part of `make sim`, because
it is slow. It writes the calculated picture to a file, which is compared
bit-accurately with a Python model of the design by the script `cmp_rtl.py`.
This requires Python with numpy. A partial picture (more than 50000 pixels)
takes about 13 minutes:
```
make run TB=main STOP_TIME=700us
sim/cmp_rtl.py
```
By default it simulates the design of the Nexys 4 DDR. The design of the
MEGA65 is simulated with
`make run TB=main STOP_TIME=700us GENERICS="G_NUM_ITERATORS=450 G_PIXELS=4"`.
See [Iterator](ALGORITHM.md#iterator) for details.

The simulation does not need any Xilinx libraries. The DSPs in the iterators
are inferred by Vivado from plain VHDL, see [Multiplier](ALGORITHM.md#multiplier).

The clock and reset module (`src/clk_rst.vhd`) uses Xilinx primitives (the
MMCM and the clock buffers), and so does the MEGA65 top level
(`src/mega65_r6.vhd`, the clock of the video DAC). They are not simulated, and
neither is the Nexys 4 DDR top level (`src/mandelbrot.vhd`), which instantiates
`clk_rst`.
