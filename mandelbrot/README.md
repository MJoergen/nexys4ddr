# Mandelbrot
This draws the [Mandelbrot set](https://en.wikipedia.org/wiki/Mandelbrot_set)
in VHDL on the Nexys 4 DDR board, which has a Xilinx Artix-7 XC7A100T FPGA. The
picture (640x480) is shown on the VGA output, and you can pan and zoom using the
buttons on the board.

All 240 DSPs of the FPGA are used in parallel for the calculation, and the
picture is stored in block RAM. Generating a complete picture takes about 7 ms,
with the main clock at 140.625 MHz.

## Implementation results
The design is built with Vivado 2025.1 and meets timing at the 140.625 MHz main
clock (setup slack +0.029 ns, hold slack +0.023 ns). The resources used are:

| Resource  | Used                  | Available
| --------- | --------------------- | ---------
| DSP48E1   | 240                   | 240
| Block RAM | 128 RAMB36 + 1 RAMB18 | 135 RAMB36
| LUTs      | about 52,000          | 63,400
| Registers | about 53,300          | 126,800

The slack is small, see [Resources and timing closure](ALGORITHM.md#resources-and-timing-closure)
for details, including the critical paths.

## Files
| File             | Description
| ---------------- | -----------
| [`src/mandelbrot.vhd`](src/mandelbrot.vhd) | Top level. The ports are mapped directly to pins on the FPGA.
| [`src/iterator.vhd`](src/iterator.vhd) | Iterates the Mandelbrot function for a single point, using one DSP.
| [`src/column.vhd`](src/column.vhd) | Calculates an entire column of the picture using one iterator.
| [`src/dispatcher.vhd`](src/dispatcher.vhd) | Controls the calculation of the entire picture, and hands out columns. Instantiates the columns.
| [`src/scheduler.vhd`](src/scheduler.vhd) | Round-robin scheduler. Used by the dispatcher both to give jobs to idle columns and to pick which column's result to accept.
| [`src/priority.vhd`](src/priority.vhd), [`src/priority_pipeline.vhd`](src/priority_pipeline.vhd) | Priority encoder, and a pipelined version built from it. Not used in the design yet, only in the `priority_pipeline` testbench.
| [`src/disp_mem.vhd`](src/disp_mem.vhd) | Display memory, holding the picture.
| [`src/disp.vhd`](src/disp.vhd), [`src/pix.vhd`](src/pix.vhd) | VGA output. Generates the sync signals and the pixel colour.
| [`src/clk.vhd`](src/clk.vhd) | Clock generation: 140.625 MHz for the calculation and 25 MHz for VGA.
| [`sim/`](sim) | Testbenches and [GTKWave](https://github.com/gtkwave/gtkwave) setups, and a simulation model of the Xilinx `mult_macro`.
| [`mandelbrot.xdc`](mandelbrot.xdc), [`mandelbrot.tcl`](mandelbrot.tcl) | Pin and timing constraints, and script for synthesis and implementation with Vivado (including the optimization directives needed to meet timing), see `make vivado`.
| [`mandelbrot.xlsx`](mandelbrot.xlsx) | Spreadsheet used during the design.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm and the design.

## Controls
The view is controlled with the buttons and switches on the board:

| Control | Description
| ------- | -----------
| `BTNL`, `BTNR`, `BTNU`, `BTND` | Pan the picture left, right, up and down.
| `BTNC` | Zoom in. With switch 2 on, zoom out instead.
| Switch 1 | Selects what the LEDs show: a free-running counter (on) or the total time the iterators have spent waiting to write to the display memory (off).
| `CPU RESET` | Resets the design and returns to the initial view.

The initial view shows the real axis from -1.67 to 1 and the imaginary axis from
-1 to 1.

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
  [GHDL](https://github.com/ghdl/ghdl), and a Vivado installation (the
  variable `XILINX_DIR`) for the Xilinx simulation libraries. It takes several
  minutes, mostly for the `dispatcher` testbench.
* `make run TB=iterator` runs a single testbench and writes the waveform to
  `sim/iterator.ghw`. Without `TB` it lists the available testbenches. It has
  the same requirements as `make sim`.
* `make check TB=iterator` does the same as `make run`, and then shows the
  waveform in [GTKWave](https://github.com/gtkwave/gtkwave).
* `make clean` removes the generated files.

## Simulation
There are testbenches in [`sim/`](sim) for `dispatcher`, `column`, `iterator`,
`mult_macro` and `priority_pipeline`. The `iterator` and `mult_macro`
testbenches are self-checking, and stop with an error if the result is wrong.
The others are investigative, i.e. they do not check the results automatically,
so you have to look at the waveforms to see that the design works as expected.

The simulation needs the Xilinx `unisim` library, which is compiled from the
Vivado installation (`XILINX_DIR`) into `sim/lib/` the first time a testbench
is run. Xilinx's source for the multiplier macro `mult_macro` does not compile
in GHDL, so [`sim/mult_macro.vhd`](sim/mult_macro.vhd) is used instead. This is
a simple model of the multiplier with a latency of one clock cycle.
