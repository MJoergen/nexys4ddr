# Mandelbrot
This draws the [Mandelbrot set](https://en.wikipedia.org/wiki/Mandelbrot_set)
in VHDL on the [Nexys 4 DDR](https://digilent.com/reference/programmable-logic/nexys-4-ddr/start)
board, which has a Xilinx Artix-7 XC7A100T FPGA. The
picture (640x480) is shown on the VGA output, and you can pan and zoom using the
buttons on the board. The same design also runs on the
[MEGA65](https://mega65.org/) (board revisions R3 and R6), which has a Xilinx
Artix-7 XC7A200T FPGA, and shows the picture in 1280x1024, see
[MEGA65](#mega65).

All 240 DSPs of the FPGA are used in parallel for the calculation, and the
picture is stored in block RAM. Generating a complete picture takes about 1.2 ms
(832 to 834 pictures per second, measured on the board), with the main clock
at 120 MHz. On the MEGA65, with 736 DSPs and the main clock at 141.64 MHz, it
takes about 2.53 ms (about 396 pictures per second; 402 were measured with the
main clock at 144 MHz), with 4.3 times as many pixels.

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
multiplications, using the identity $x^2 - y^2 = (x+y)(x-y)$. Each of the 120
job modules contains an iterator with two DSP multipliers, one for each
multiplication, and the iterator calculates one iteration in every clock
cycle. Most points in the
set are found long before the maximum count, because the values of $z$ start
to repeat exactly (periodicity detection). The picture is divided into jobs,
each of 120 rows of a picture column, and the dispatcher gives the next job to
a job module as soon as it is idle.

[ALGORITHM.md](ALGORITHM.md) explains the design in detail: the number format,
the multiplier, the iterator (including how overflow is detected), the jobs,
the dispatcher, and the timing and resource usage.

## Controls
A new picture is only calculated when the view changes, and after reset. In
between, the job modules are idle, and the FPGA uses much less power (see
[The top level](ALGORITHM.md#the-top-level)). The view is controlled with the
buttons and switches on the board. The switch numbers are the bit numbers of
the switch input, i.e. `SW0` to `SW7` on the board.

| Control | Description
| ------- | -----------
| `BTNL`, `BTNR`, `BTNU`, `BTND` | Pan the picture left, right, up, and down, by one pixel for each update. Panning stops at the edge of the number range (-2 to 2).
| `BTNC` | Zoom in. With switch 2 on, zoom out instead. The centre of the picture stays fixed, except when zooming out would move an edge of the view beyond -2 or 2; then the view is moved instead. Zooming stops at the smallest pixel size (2^-16), and when the view can not get larger.
| Switches 0 and 1 | Select the colour palette (switch 1 is the high bit). 0 (both off): the lower 8 bits of the count are the colour (RRRGGGBB), mostly blue and green, and the set is white. 1: rainbow, the hue goes around the colour circle every 16 counts. 2: fire, black, red, orange, yellow, and white, with the square root of the count. 3: blue, white, orange, and dark brown, with the logarithm of the count. In the palettes 1 to 3 the set is black.
| Switches 3 to 7 | Not used.
| `CPU RESET` | Resets the design and returns to the initial view.

While a button is held down, the view is updated about 18 times per second.
Each update pans by one pixel, or changes the size of a pixel by about 1.6%
(roughly 33% per second). The initial view shows the real axis from -1.67 to 1
and the imaginary axis from -1 to 1 (-1.07 to 1.07 on the MEGA65). See
[The top level](ALGORITHM.md#the-top-level) for details.

The 7-segment display shows the frame rate, i.e. the number of pictures the
design could calculate per second, rounded down to an integer. It is the
clock frequency divided by the time taken by the latest picture (the one on
the screen), and it is updated after every picture. The same frame rate is
also shown in the top right corner of the VGA output, in white on black.

### MEGA65
The MEGA65 has no buttons, switches, or 7-segment display, so the view is
controlled with a joystick in each port, or with the keyboard, see
[`src/mega65.vhd`](src/mega65.vhd). The VGA output is on the VGA
connector.

The board revisions R3 and R6 have the same FPGA, and the design is the
same, but some of the pins are different, so each revision has its own top
level module and bit-file (`make mega65-r3` and `make mega65-r6`), and the
bit-file of one revision must not be used on the other one. The R6 can pull
each joystick line low from the FPGA, and the design for the R6 must switch
this off, otherwise the joystick lines can be read as pressed, see
[`src/mega65_r6.vhd`](src/mega65_r6.vhd). The R3 does not have these
outputs, and the pins are used for other things.

| Control | Description
| ------- | -----------
| Joystick port 1: left, right, up, down, or the cursor keys | Pan the picture, like `BTNL`, `BTNR`, `BTNU`, and `BTND`.
| Joystick port 1: fire, or the `+` key | Zoom in, like `BTNC`.
| Joystick port 2: fire, or the `-` key | Zoom out, like `BTNC` with switch 2 on.
| Reset button | Resets the design and returns to the initial view, like `CPU RESET`. Only on the R6: on the R3 the reset button is read by the MAX10 (a small FPGA on the board), not by the XC7A200T, so the design is only reset after power-on.

The colour palette is always palette 0, and the frame rate is only shown on the
VGA output.

The VGA output is 1280x1024 at 60 Hz (with a pixel clock of 108 MHz) instead
of 640x480. The aspect ratio is 5:4 instead of 4:3, so the initial view shows
the same real axis, and a little more of the imaginary axis (-1.07 to 1.07),
with 4.3 times as many pixels. The display memory has 1280x1024 pixels in 320
BRAMs (of the 365 in the XC7A200T), with 21 bits of address (the column and
the row). Most monitors accept 1280x1024; a widescreen monitor shows it with
black bars or stretched.

The XC7A200T is larger, so the design uses 368 job modules (736 of the 740
DSPs) instead of 120, see [`src/mega65.vhd`](src/mega65.vhd). The main
clock is 141.64 MHz. Both boards write four pixels (consecutive rows of a
picture column) to the display memory at a time. The display memory takes
one write per clock cycle, so with one pixel in each write the picture would
take at least 1280x1024 clock cycles (9.25 ms), whatever the number of job
modules. With four pixels in each write the picture takes about 2.53 ms,
i.e. about 396 pictures per second (the model; an R3 showed 402 with the main
clock at 144 MHz, the same as the model), close to the limit of the display
memory (2.31 ms). If every pixel needed the maximum count, it would take
13.2 ms (75 pictures per second), still above the 60 Hz of the VGA output,
see [MEGA65](ALGORITHM.md#mega65).

## Implementation results
The design is built with Vivado 2025.1. The timing of the longest path (in
the iterators) is very close, and the setup slack varies by about 0.1 ns
between runs, see below.

The resource usage is:

| Resource           | Nexys 4 DDR (XC7A100T-1) | Available | MEGA65 (XC7A200T-2)    | Available
| ------------------ | ------------------------ | --------- | ---------------------- | ---------
| DSP48E1            | 240 (100%)               | 240       | 736 (99%)              | 740
| Block RAM (RAMB36) | 128.5 (95%)              | 135       | 321 (88%)              | 365
| Slices             | 9,186 (58%)              | 15,850    | 21,665 (64%)           | 33,650
| LUTs               | 16,420 (26%)             | 63,400    | 46,903 (35%)           | 134,600
| Registers          | 26,555 (21%)             | 126,800   | 58,546 (22%)           | 269,200

The performance and timing are:

|                 | Nexys 4 DDR        | MEGA65
| --------------- | ------------------ | --------------
| Resolution      | 640x480            | 1280x1024
| Clock frequency | 120.00 MHz         | 141.64 MHz
| Initial FPS     | 832-834 (measured) | 396 (estimated; 402 measured at 144 MHz)
| Worst-case FPS  | 87 (estimated)     | 75 (estimated)
| Setup slack     | -0.001 ns          | +0.021 ns (at 144 MHz)
| Hold slack      | +0.050 ns          | +0.025 ns (at 144 MHz)

The numbers for the MEGA65 are from the build for the R6, with the main
clock at 144 MHz. The build for the R3 at 144 MHz failed timing by 0.076 ns
(21,723 slices, +0.022 ns hold slack), so the main clock has since been
reduced to 141.64 MHz, which gives 0.116 ns more setup slack, but this has
not been built yet. The last build for the Nexys 4 DDR failed timing by
0.001 ns, and the one before met it with +0.026 ns. See
[Resources and timing closure](ALGORITHM.md#resources-and-timing-closure)
for details.

## Running
Type `make` to list the supported targets. The most important ones are:
* `make nexys4ddr` synthesizes and implements the design using
  [Vivado](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html),
  and generates `build/nexys4ddr/nexys4ddr.bit`. It expects Vivado in
  `/opt/Xilinx/2025.1/Vivado` (the variable `XILINX_DIR`). It takes about 6
  minutes. Vivado is run in `build/nexys4ddr/`, so the log (`vivado.log`), the
  routed checkpoint (`nexys4ddr.dcp`), and the other files from Vivado are
  there too.
* `make mega65-r3` and `make mega65-r6` do the same for the MEGA65 R3 and R6,
  in `build/mega65-r3/` and `build/mega65-r6/`, and generate
  `build/mega65-r3/mega65-r3.bit` and `build/mega65-r6/mega65-r6.bit`. Each
  takes about 13 minutes, see [MEGA65](ALGORITHM.md#mega65). Because each
  board has its own directory, they can all be built at the same time with
  `make -j3 nexys4ddr mega65-r3 mega65-r6`.
* `make fpga` programs the Nexys 4 DDR board with `build/nexys4ddr/nexys4ddr.bit`, using `djtgcfg` from
  Digilent Adept.
* `make sim` runs all the testbenches in parallel, without opening the
  waveform viewer, see [below](#simulation). This requires
  [GHDL](https://github.com/ghdl/ghdl). It uses one job per CPU (set
  `SIM_JOBS` to change that), writes the output of each testbench to
  `build/<name>.log`, and ends with a pass/fail summary. It takes about 9
  minutes, almost all of which is the `vga` testbench (because of 1280x1024).
* `make run TB=iterator` runs a single testbench. It does not write a
  waveform, because that makes the simulation much slower. Without `TB` it
  lists the available testbenches. It has the same requirements as
  `make sim`.
* `make check TB=iterator` runs a single testbench like `make run`, but also
  writes the waveform to `sim/iterator.ghw`, and then shows it in
  [GTKWave](https://github.com/gtkwave/gtkwave).
* `make formal` runs the formal verification, see
  [below](#formal-verification). This requires
  [SymbiYosys](https://github.com/YosysHQ/sby), Yosys with the
  [GHDL plugin](https://github.com/ghdl/ghdl-yosys-plugin), and an SMT solver
  (Yices), e.g. from the [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build).
  It takes about 20 seconds.
* `make clean` removes the generated files.

## Simulation
There are testbenches in [`sim/`](sim) for `dispatcher`, `job`, `iterator`,
`job_scheduler`, `res_scheduler`, `view`, `vga`, `overlay`, `disp_mem`, and
`fps`, and one (`redraw`) which checks that `main` only calculates a picture
when the view changes, and that the pictures end up in the display memory.
All of them are self-checking, and stop with an error if the result is wrong.
They stop by themselves when they are finished.

There is also a testbench for `main`, which is not part of `make sim`, because
it is slow. It writes the calculated picture to a file, which is compared
bit-accurately with a Python model of the design by the script `cmp_rtl.py`.
This requires Python with numpy. A partial picture (about 50000 pixels)
takes about 5 minutes:
```
make run TB=main STOP_TIME=200us
sim/cmp_rtl.py
```
By default it simulates the design of the Nexys 4 DDR. The design of the
MEGA65 is simulated with
```
make run TB=main STOP_TIME=200us GENERICS="G_NUM_ITERATORS=368 G_PIXELS=4 G_ROWS_IN_JOB=64 G_NUM_COLS=1280 G_NUM_ROWS=1024 G_COL_STRIDE=1024 G_ADDR_BITS=21"
```
See [Iterator](ALGORITHM.md#iterator) for details.

The simulation does not need any Xilinx libraries. The DSPs in the iterators
are inferred by Vivado from plain VHDL, see [Multiplier](ALGORITHM.md#multiplier).

The clock and reset module (`src/clk_rst.vhd`) uses Xilinx primitives (the
MMCM and the clock buffers), and so does the design of the MEGA65
(`src/mega65.vhd`, the clock of the video DAC). They are not simulated, and
neither are the top levels (`src/nexys4ddr.vhd`, `src/mega65_r3.vhd`, and
`src/mega65_r6.vhd`), which instantiate them.

## Formal verification
There are formal proofs in [`formal/`](formal) for `res_scheduler`,
`job_scheduler`, `job`, and `dispatcher_jobs`. The properties of each module are in a PSL file
(`<name>.psl`), which is bound to the module, so the modules themselves are not
changed. Each module is proved for a few sets of generics (see `<name>.sby`),
with k-induction, and cover statements check that the interesting cases are
reachable. The properties are:
* `res_scheduler`: Only a process that is ready is selected, and only while
  the scheduler is active. Each result is selected only once. A process that
  stays ready is selected within a bounded time, also when all the processes
  are ready (the order is fair), and the bound is reached.
* `job_scheduler`: Only an idle process is started, and only while the
  scheduler is active. The processes are visited in order, and an idle
  process is always started when it is visited, so it is started within
  `G_SIZE`+1 clock cycles.
* `job`: The job module is busy from the start of a job until its last result
  is acknowledged. The results come in order, one for each group of
  `G_PIXELS` rows, with the row number of the first row. A result stays
  unchanged until it is acknowledged, and is then removed. Each result has the
  counts of its rows from the iterator. The iterator is started once for each
  row, with the value of c of that row, and c does not change while it
  iterates.
* `dispatcher_jobs` (with `job_scheduler`): The jobs of a picture are given
  out in order, one block at a time, each once. The job module given a job is
  started in the next clock cycle, with the value of c of the first row of
  the job. The picture is done only when all its jobs have been given out and
  all the job modules are idle, and then within two clock cycles. It also
  meets the assumptions about the inputs of the job module in `job.psl`: a job
  module is only started when it is idle (this needs at least five job
  modules; with four, a job is started twice), not right after its reset, and
  the step in cy does not change while it is busy. The job modules are not
  included; their busy flags are given by assumptions. A new picture must
  only be started when the previous one is done, as `main` does.

For `job`, the iterator is replaced by a stub
([`formal/iterator_stub.vhd`](formal/iterator_stub.vhd)) whose outputs are
chosen freely by the solver. Its handshake (done goes low after a start, goes
high after any number of clock cycles, and then stays high with an unchanged
count until the next start) is given by assumptions in `job.psl`. So the count
of each row can be any value, and the iteration can take any number of clock
cycles. The iterator itself is checked by simulation, see above.

## Files
The files used only in the MAIN clock domain are in [`src/main/`](src/main),
and those used only in the VGA clock domain are in [`src/vga/`](src/vga). The
files that are in both clock domains are in [`src/`](src).

| File             | Description
| ---------------- | -----------
| [`src/nexys4ddr.vhd`](src/nexys4ddr.vhd) | Top level. The ports are mapped directly to pins on the FPGA. Instantiates the clock and reset generation, the display memory, and the two modules below, and moves the frame rate from the MAIN clock domain to the VGA clock domain.
| [`src/mega65.vhd`](src/mega65.vhd) | The design for the MEGA65. The same as `nexys4ddr.vhd`, but with the ports of the MEGA65, more job modules, a larger display memory, and a resolution of 1280x1024. Used by the two top levels below.
| [`src/mega65_r3.vhd`](src/mega65_r3.vhd), [`src/mega65_r6.vhd`](src/mega65_r6.vhd) | Top levels for the MEGA65 R3 and R6. They connect `mega65.vhd` to the pins of each board revision. The R6 also switches off the outputs that pull the joystick lines low, and switches on the power of the joysticks and of the video DAC.
| [`src/keyboard/`](src/keyboard) | MEGA65 keyboard driver, from the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework (via [C64MEGA65](https://github.com/MJoergen/C64MEGA65), GPL v3). `m2m_keyb` reads the keyboard, and cycles through the keys, showing whether each of them is pressed. Only used by `mega65.vhd`.
| [`src/main/main.vhd`](src/main/main.vhd) | Everything in the MAIN clock domain: view control from buttons and switches, the dispatcher, and the frame rate (shown on the 7-segment display and on the VGA output).
| [`src/main/view.vhd`](src/main/view.vhd) | View control. Pans and zooms the view, and keeps it inside the range of the number format.
| [`src/main/fps.vhd`](src/main/fps.vhd), [`src/main/seg.vhd`](src/main/seg.vhd) | Frame rate. `fps` divides the clock frequency by the time taken by the latest picture (it can also average the time, but `main` does not use that), and converts the result to decimal, and `seg` multiplexes the digits on the 7-segment display.
| [`src/vga/vga.vhd`](src/vga/vga.vhd) | Everything in the VGA clock domain: pixel counters, VGA output, and the frame rate overlay.
| [`src/main/iterator.vhd`](src/main/iterator.vhd) | Iterates the Mandelbrot function for a single point, one iteration in each clock cycle, using two DSPs.
| [`src/main/job.vhd`](src/main/job.vhd) | A job module. Calculates one job (120 rows of a picture column, or 64 on the MEGA65) at a time, using one iterator.
| [`src/main/dispatcher.vhd`](src/main/dispatcher.vhd) | Controls the calculation of the entire picture: hands out the jobs to the idle job modules, and collects the results. Instantiates the job modules, between its two parts below.
| [`src/main/dispatcher_jobs.vhd`](src/main/dispatcher_jobs.vhd) | First part of the dispatcher: hands out the jobs to the idle job modules, and finds out when the picture is done.
| [`src/main/dispatcher_results.vhd`](src/main/dispatcher_results.vhd) | Second part of the dispatcher: collects the results, and writes them to the display memory.
| [`src/main/dispatcher_pkg.vhd`](src/main/dispatcher_pkg.vhd) | Types used in the ports of the two parts of the dispatcher.
| [`src/main/job_scheduler.vhd`](src/main/job_scheduler.vhd) | Round-robin scheduler. Used by dispatcher\_jobs to give jobs to idle job modules.
| [`src/main/res_scheduler.vhd`](src/main/res_scheduler.vhd) | Scheduler for the results. Used by dispatcher\_results to pick which job module's result to accept, from the job modules that have a result ready.
| [`src/disp_mem.vhd`](src/disp_mem.vhd) | Display memory, holding the picture, in blocks of 4096 pixels (one BRAM each): 128 on the Nexys 4 DDR, and 320 on the MEGA65.
| [`src/vga/pix.vhd`](src/vga/pix.vhd), [`src/vga/disp.vhd`](src/vga/disp.vhd) | VGA output. `pix` generates the pixel counters, and `disp` generates the sync signals and the pixel colour.
| [`src/vga/video_pkg.vhd`](src/vga/video_pkg.vhd) | The video modes, i.e. the resolution and the timing of the VGA output: 640x480 (Nexys 4 DDR) and 1280x1024 (MEGA65), both at 60 Hz.
| [`src/vga/palette_pkg.vhd`](src/vga/palette_pkg.vhd) | The four colour palettes, which convert the count of a pixel to its colour.
| [`src/vga/overlay.vhd`](src/vga/overlay.vhd), [`src/vga/font_pkg.vhd`](src/vga/font_pkg.vhd) | Frame rate overlay. `overlay` shows the frame rate in the top right corner of the picture, with the digits of the font in `font_pkg`.
| [`font/`](font) | The script that generates `font_pkg.vhd` from the [Spleen](https://github.com/fcambus/spleen) 16x32 font, and the license of the font (BSD 2-Clause, see [`font/LICENSE.spleen`](font/LICENSE.spleen)).
| [`src/clk_rst.vhd`](src/clk_rst.vhd) | Clock and reset generation: the main clock for the calculation (120 MHz, or 141.64 MHz on the MEGA65) and the pixel clock for VGA (25 MHz for 640x480, 108 MHz for 1280x1024), each with a synchronous reset.
| [`sim/`](sim) | Testbenches and [GTKWave](https://github.com/gtkwave/gtkwave) setups, a Python model of the iterator count (`iterator_model.py`), a vectorized model of the complete picture (`model.py`), the same bit-accurate model in VHDL (`iterator_model_pkg.vhd`, used by the testbenches), and a script (`cmp_rtl.py`) that compares the output of the testbench `main_tb` with this model.
| [`formal/`](formal) | Formal verification with [SymbiYosys](https://github.com/YosysHQ/sby): the properties of each module (`<name>.psl`), the tasks (`<name>.sby`), and the iterator stub used for `job`, see [Formal verification](#formal-verification).
| [`nexys4ddr.xdc`](nexys4ddr.xdc), [`mega65-r3.xdc`](mega65-r3.xdc), [`mega65-r6.xdc`](mega65-r6.xdc), [`mandelbrot.tcl`](mandelbrot.tcl) | Pin and timing constraints for each board, and script for synthesis and implementation with Vivado (including the optimization directives needed to meet timing), see `make nexys4ddr`. The script gets the FPGA part, the top level, and the list of source files from the Makefile, so it must be run through `make nexys4ddr`, `make mega65-r3`, or `make mega65-r6`.
| [`mandelbrot.xlsx`](mandelbrot.xlsx) | Spreadsheet used during the design. It iterates the example point -1+0.5i from [the iterator section](ALGORITHM.md#iterator) using real numbers.
| [`ALGORITHM.md`](ALGORITHM.md) | Detailed explanation of the algorithm and the design.
| [`TODO.md`](TODO.md) | Ideas for further changes.
