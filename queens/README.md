# Queens
This solves the [eight queens puzzle](https://en.wikipedia.org/wiki/Eight_queens_puzzle)
in VHDL on the [Nexys 4 DDR](https://digilent.com/reference/programmable-logic/nexys-4-ddr/start)
board, which has a Xilinx Artix-7 XC7A100T FPGA. The puzzle is to place eight
queens on a chess board so that no two queens attack each other, i.e. no two
queens share a row, a column, or a diagonal. There are 92 solutions.

The design searches through the board positions one step at a time, slowly
enough that you can watch it. The current board is shown on the VGA output
(640x480), and the 7-segment display shows either the number of solutions
found so far or the number of positions visited so far.

## The algorithm
The board always has exactly one queen in each row, so it is stored as a
64-bit vector with one bit per square, where bit `row*8 + col` is set when
there is a queen on that square. After reset, every queen is in the rightmost
column.

For each row, a combinational network checks whether the queen in that row
is attacked by any queen in the rows above it. It keeps three running ORs of
the rows above: one for the columns, and one for each diagonal direction (the
diagonal ORs are shifted one column per row). The signal `valid(row)` is true
when the rows 0 to `row` contain no attacking queens, and the board is a
solution when `valid(7)` is true.

Every step moves to the next position, with backtracking: the design finds
the lowest row whose rows above are all valid, and moves the queen in that
row one column to the left. Every row below it is reset, so that its queen is
in the rightmost column again. If the queen is already in the leftmost
column, that row is also reset, and the row above is moved instead. So when a
partial board is already invalid, all the positions below it are skipped.
When the queen in the top row moves past the leftmost column, the search is
done and the board stops changing.

The search for the 8x8 board visits 13,756 positions, and finds all 92
solutions.

## Controls
* Switch 0: Reset. Set it to restart the search, and clear it to run.
* Switch 1: Selects what the 7-segment display shows, in decimal. When it is
  set, the display shows the number of solutions found. When it is clear, the
  display shows the number of positions visited (this keeps counting after
  the search is done).
* Switches 2-7: The speed, as a 6-bit number (switch 2 is the least
  significant bit). The board takes about speed/4 steps per second, so the
  fastest speed (all six switches set) is about 16 steps per second, and the
  whole search then takes about 15 minutes. When all six switches are clear,
  the search is paused.

The LEDs above the switches show the state of the switches.

## Files
The sources are in the [src](src) directory:

* [queens_top.vhd](src/queens_top.vhd): Top level. It connects the modules
  below, and counts the solutions and positions.
* [queens.vhd](src/queens.vhd): The board, the checking of the board, and the
  backtracking search. The board size is the generic `G_NUM_QUEENS`.
* [counter.vhd](src/counter.vhd): Generates a pulse for every step of the
  search, at a rate set by switches 2-7.
* [clk.vhd](src/clk.vhd): A PLL that makes the 25 MHz clock used by the VGA
  output and the search from the 100 MHz board clock.
* [vga.vhd](src/vga.vhd), [vga_ctrl.vhd](src/vga_ctrl.vhd),
  [vga_disp_queens.vhd](src/vga_disp_queens.vhd) and
  [vga_bitmap_pkg.vhd](src/vga_bitmap_pkg.vhd): The VGA output. `vga_ctrl`
  makes the 640x480 timing, and `vga_disp_queens` draws the board, with
  squares of 32x32 pixels and the queen bitmap from `vga_bitmap_pkg`.
* [display.vhd](src/display.vhd),
  [display_int2seg.vhd](src/display_int2seg.vhd),
  [display_digit.vhd](src/display_digit.vhd) and
  [display_seg.vhd](src/display_seg.vhd): Converts a number to four decimal
  digits and drives the 7-segment display.
* [queens_top.xdc](src/queens_top.xdc): Pin locations and the clock
  constraint.

The simulation files are in the [sim](sim) directory:

* [queens_tb.vhd](sim/queens_tb.vhd): Testbench for the `queens` module on a
  4x4 board. It checks that every solution has one queen in each column, and
  that the search finds the 2 solutions of the 4x4 board.
* [queens_top_tb.vhd](sim/queens_top_tb.vhd): Testbench for the whole design.
* [queens_tb.gtkw](sim/queens_tb.gtkw) and
  [queens_top_tb.gtkw](sim/queens_top_tb.gtkw): GTKWave save files with the
  signals to show for each testbench.

## Building
The [Makefile](Makefile) uses an open source tool flow:
[GHDL](https://github.com/ghdl/ghdl) for simulation,
[Yosys](https://github.com/YosysHQ/yosys) with the
[ghdl-yosys-plugin](https://github.com/ghdl/ghdl-yosys-plugin) for synthesis,
[nextpnr-xilinx](https://github.com/gatecat/nextpnr-xilinx) for place and
route, and [Project X-Ray](https://github.com/f4pga/prjxray) to make the
bit-file. The Xilinx `unisim` library (for the PLL) is read from a Vivado
installation, given by `XILINX_DIR` (default `/opt/Xilinx/Vivado/2019.2`).
The simulation waveform files (`.ghw`) are written to the `sim` directory.

* `make sim`: Simulates `queens_tb` and shows the waveform in GTKWave.
* `make sim_top`: Simulates `queens_top_tb` and shows the waveform in GTKWave.
* `make synth`: Makes the bit-file `queens.bit`. This needs the variable
  `XRAY_DIR` to point to Project X-Ray, and `NEXTPNR` to point to
  nextpnr-xilinx, for example
  `make synth XRAY_DIR=~/prjxray NEXTPNR=~/nextpnr-xilinx`.
* `make clean`: Deletes the generated files.

You can then program the board with the bit-file, for example with
[openFPGALoader](https://github.com/trabucayre/openFPGALoader)
(`openFPGALoader -b nexys_a7_100 queens.bit`) or with the Vivado hardware
manager.

There is also a Vivado project in [vivado/vivado.xpr](vivado/vivado.xpr).
