# Mandelbrot
This draws the [Mandelbrot set](https://en.wikipedia.org/wiki/Mandelbrot_set)
in VHDL on the Nexys 4 DDR board, which has a Xilinx Artix-7 XC7A100T FPGA. The
picture (640x480) is shown on the VGA output, and you can pan and zoom using the
buttons on the board.

All 240 DSPs of the FPGA are used in parallel for the calculation, and the
picture is stored in block RAM. Generating a complete picture takes about 7 ms,
with the main clock at 140.625 MHz.

## The algorithm
For each pixel, which corresponds to a complex number $c$, we iterate
$z \mapsto z^2 + c$ starting from $z = 0$, and count the number of iterations
until the real or the imaginary part of $z$ leaves the range -2 to 2 (the range
of the number format), up to a maximum of 511. This count decides the colour of
the pixel.

The numbers are 18-bit
[fixed point](https://en.wikipedia.org/wiki/Fixed-point_arithmetic) (2 integer
bits and 16 fractional bits), and each iteration needs only two real
multiplications, using the identity $x^2 - y^2 = (x+y)(x-y)$. Each of the 240
column modules contains an iterator with a single DSP multiplier, and the
iterator calculates one iteration every three clock cycles. The picture is
divided into picture columns, and the dispatcher gives the next picture column
to a column module as soon as it is idle.

[ALGORITHM.md](ALGORITHM.md) explains the design in detail: the number format,
the multiplier, the iterator (including how overflow is detected), the columns,
the dispatcher, and the timing and resource usage.

## Implementation results
The design is built with Vivado 2025.1 and meets timing at the 140.625 MHz main
clock (setup slack +0.008 ns, hold slack +0.029 ns). The resources used are:

| Resource  | Used                  | Available
| --------- | --------------------- | ---------
| DSP48E1   | 240                   | 240
| Block RAM | 128 RAMB36 + 1 RAMB18 | 135 RAMB36
| LUTs      | about 61,900 (cells)  | 63,400
| Registers | about 53,800          | 126,800

The slack is small, and the LUTs are almost all used, see
[Resources and timing closure](ALGORITHM.md#resources-and-timing-closure)
for details.

## Files
| File             | Description
| ---------------- | -----------
| [`src/mandelbrot.vhd`](src/mandelbrot.vhd) | Top level. The ports are mapped directly to pins on the FPGA. Instantiates the clock generation, the display memory, and the two modules below, and generates the resets.
| [`src/main.vhd`](src/main.vhd) | Everything in the MAIN clock domain: view control from buttons and switches, the dispatcher, and the LEDs.
| [`src/view.vhd`](src/view.vhd) | View control. Pans and zooms the view, and keeps it inside the range of the number format.
| [`src/vga.vhd`](src/vga.vhd) | Everything in the VGA clock domain: pixel counters and VGA output.
| [`src/iterator.vhd`](src/iterator.vhd) | Iterates the Mandelbrot function for a single point, using one DSP.
| [`src/column.vhd`](src/column.vhd) | A column module. Calculates one picture column (all its rows) at a time, using one iterator.
| [`src/dispatcher.vhd`](src/dispatcher.vhd) | Controls the calculation of the entire picture: hands out the picture columns to the idle column modules, and collects the results. Instantiates the column modules.
| [`src/scheduler.vhd`](src/scheduler.vhd) | Round-robin scheduler. Used by the dispatcher both to give jobs to idle column modules and to pick which column module's result to accept.
| [`src/priority.vhd`](src/priority.vhd), [`src/priority_pipeline.vhd`](src/priority_pipeline.vhd) | Priority encoder, and a pipelined version built from it. Not used in the design yet, only in the `priority_pipeline` testbench.
| [`src/disp_mem.vhd`](src/disp_mem.vhd) | Display memory, holding the picture.
| [`src/disp.vhd`](src/disp.vhd), [`src/pix.vhd`](src/pix.vhd) | VGA output. Generates the sync signals and the pixel colour.
| [`src/clk.vhd`](src/clk.vhd) | Clock generation: 140.625 MHz for the calculation and 25 MHz for VGA.
| [`sim/`](sim) | Testbenches and [GTKWave](https://github.com/gtkwave/gtkwave) setups, a simulation model of the Xilinx `mult_macro`, a Python model of the iterator count (`iterator_model.py`), a vectorized model of the complete picture (`model.py`), the same bit-accurate model in VHDL (`iterator_model_pkg.vhd`, used by the testbenches), and a script (`cmp_rtl.py`) that compares the output of the testbench `main_tb` with this model.
| [`mandelbrot.xdc`](mandelbrot.xdc), [`mandelbrot.tcl`](mandelbrot.tcl) | Pin and timing constraints, and script for synthesis and implementation with Vivado (including the optimization directives needed to meet timing), see `make vivado`.
| [`mandelbrot.xlsx`](mandelbrot.xlsx) | Spreadsheet used during the design.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm and the design.

## Controls
The picture is recalculated continuously: as soon as one picture is finished,
the next one is started. The view is controlled with the buttons and switches on
the board. The switch numbers are the bit numbers of the switch input, i.e.
`SW0` to `SW7` on the board.

| Control | Description
| ------- | -----------
| `BTNL`, `BTNR`, `BTNU`, `BTND` | Pan the picture left, right, up and down, by one pixel for each update. Panning stops at the edge of the number range (-2 to 2).
| `BTNC` | Zoom in. With switch 2 on, zoom out instead. The top left corner of the view stays fixed, except when zooming out would move the right or bottom edge beyond 2; then the view is moved left or up instead. Zooming stops at the smallest pixel size (2^-16), and when the view can not get larger.
| Switch 1 | Selects what the LEDs show. On: the time since the start of the current picture, in units of 14.6 us (2^11 clock cycles). It restarts for each picture. Off: the total time that the column modules have spent waiting for their results to be accepted, summed up over all column modules, in the same unit. It is accumulated since reset.
| Switches 0 and 3 to 7 | Not used.
| `CPU RESET` | Resets the design and returns to the initial view.

While a button is held down, the view is updated about 17 times per second. Each
update pans by one pixel, or changes the size of a pixel by about 1.6%
(roughly 30% per second). The initial view shows the real axis from -1.67 to 1
and the imaginary axis from -1 to 1. See
[The top level](ALGORITHM.md#the-top-level) for details.

## Running
Type `make` to list the supported targets. The most important ones are:
* `make vivado` synthesizes and implements the design using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html),
  and generates `mandelbrot.bit`. It expects Vivado in
  `/opt/Xilinx/2025.1/Vivado` (the variable `XILINX_DIR`). It takes about 10
  minutes, and writes the log to `vivado.log`.
* `make fpga` programs the board with `mandelbrot.bit`, using `djtgcfg` from
  Digilent Adept.
* `make sim` runs all the testbenches one after another, without opening the
  waveform viewer, see [below](#simulation). This requires
  [GHDL](https://github.com/ghdl/ghdl). It takes about 40 seconds.
* `make run TB=iterator` runs a single testbench and writes the waveform to
  `sim/iterator.ghw`. Without `TB` it lists the available testbenches. It has
  the same requirements as `make sim`.
* `make check TB=iterator` does the same as `make run`, and then shows the
  waveform in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

## Simulation
There are testbenches in [`sim/`](sim) for `dispatcher`, `column`, `iterator`,
`scheduler`, `view`, `vga`, `mult_macro` and `priority_pipeline`. All of them are
self-checking, and stop with an error if the result is wrong. Most of them stop
by themselves when they are finished. The `priority_pipeline` testbench compares
the module with the simple `priority` module for all 65536 input vectors, which
takes 655 us of simulated time, and it is stopped by the maximum simulation time
in the Makefile (`STOP_TIME`).

There is also a testbench for `main`, which is not part of `make sim`, because
it is slow. It writes the calculated picture to a file, which is compared
bit-accurately with a Python model of the design by the script `cmp_rtl.py`.
This requires Python with numpy. A partial picture (more than 50000 pixels)
takes about 13 minutes:
```
make run TB=main STOP_TIME=700us
sim/cmp_rtl.py
```
See [Iterator](ALGORITHM.md#iterator) for details.

The simulation does not need any Xilinx libraries. Xilinx's source for the
multiplier macro `mult_macro` does not compile in GHDL, so
[`sim/mult_macro.vhd`](sim/mult_macro.vhd) is used instead. This is a simple
model of the multiplier with a latency of one clock cycle. It is compiled into
the library `unimacro` in `sim/lib/` the first time a testbench is run.

The clock module (`src/clk.vhd`) and the top level (`src/mandelbrot.vhd`) use
Xilinx primitives, and are not simulated.
