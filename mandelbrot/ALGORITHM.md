# The algorithm and its implementation
This describes in some detail how the Mandelbrot design works, and the main
parts it is built from. See [README.md](README.md) for an overview, a list of
files, and how to build and run the design.

The design is implemented on the Nexys 4 DDR board, which uses a Xilinx FPGA
XC7A100T. This FPGA has a total of 240 DSPs, which are all used for the actual
calculations. Additionally, the FPGA contains 135 BRAMs (of 36 kbit each),
which are used for storing the results of the calculation, i.e. the actual
picture to be displayed.

## Instantiation hierarchy
The modules are instantiated as follows:
```
mandelbrot                      src/mandelbrot.vhd (top level)
 +- clk                         src/clk.vhd (MMCM and clock buffers)
 +- main                        src/main.vhd (MAIN clock domain)
 |   +- view                    src/view.vhd (view control from the buttons)
 |   +- dispatcher              src/dispatcher.vhd
 |       +- scheduler           (i_scheduler, selects the column module to receive a job)
 |       +- column  (x 240)     src/column.vhd (the column modules)
 |       |   +- iterator        src/iterator.vhd
 |       |       +- mult_macro  (Xilinx unimacro, uses one DSP)
 |       +- scheduler           (i_scheduler_res, selects the column module whose result is accepted)
 +- disp_mem                    src/disp_mem.vhd (display memory)
 +- vga                         src/vga.vhd (VGA clock domain)
     +- pix                     src/pix.vhd (pixel counters)
     +- disp                    src/disp.vhd (VGA output)
```
The number of column modules (and therefore iterators and DSPs) is set by the
generic `G_NUM_ITERATORS`, which the top level sets to 240.

The files `src/priority.vhd` and `src/priority_pipeline.vhd` are not part of
this hierarchy. The module `priority_pipeline` instantiates two `priority`
modules, but is itself only instantiated by its own testbench
([`sim/priority_pipeline_tb.vhd`](sim/priority_pipeline_tb.vhd)). The
scheduler does not use them.

## The Mandelbrot iteration
For each point $c = c_x + i c_y$ in the picture, we iterate
$z_{n+1} = z_n^2 + c$, starting from $z_0 = 0$. The number of iterations needed
before the real or the imaginary part of $z$ is outside the range -2 to 2 (or a
maximum iteration count is reached) is used to colour the pixel, see
[Overflow](#overflow).

The usual test is whether $|z|$ is larger than 2. If the real or the imaginary
part is outside the range -2 to 2, then $|z|$ is at least 2, so the test used
here detects the points outside the Mandelbrot set too, only sometimes a few
iterations later (the count differs by at most 2 for the initial view). The
points that are shown as inside the set are the same with both tests, except
for points where $|z|$ becomes exactly 2, such as $c = -2$ (see
[Overflow](#overflow)).

Writing $z = x + iy$, the iteration is
```
new_x = x*x - y*y + cx
new_y = 2*x*y + cy
```
This can be rewritten to use only two (real) multiplications:
```
new_x = (x+y)*(x-y) + cx
new_y = 2*(x*y) + cy
```

## Fixed point arithmetic
Numbers are represented as "fixed point binary two's complement". Specifically,
2.16 bit representation is used, i.e. two bits for the integer portion, and 16
bits for the fraction part.

This means we can represent real numbers in the range -2 .. 2, with an accuracy
of 0.5^16, i.e. about 5 decimal places of accuracy. A real number x is
represented using the binary number of x\*2^16, if x is positive, and
(x+4)\*2^16 if x is negative.

The first bit acts as a sign bit. It is '1' if the number is negative, and it
is '0' if the number is positive.

Some examples are:
```
-2        : 10.0000000000000000
-1.5      : 10.1000000000000000
-1        : 11.0000000000000000
-0.000015 : 11.1111111111111111
 0        : 00.0000000000000000
 0.000015 : 00.0000000000000001
 0.5      : 00.1000000000000000
 1        : 01.0000000000000000
 1.5      : 01.1000000000000000
```

## Multiplier
The built-in DSP provides a 25x18-bit signed multiplier. The iterator uses it
as a 19x18-bit multiplier, with the first input in 3.16 bit representation and
the second input in 2.16 bit representation (see [Overflow](#overflow) for why
the first input has 19 bits). This generates a 37-bit result in 5.32 bit
representation. The products in the iterator are always between -4 and 4, so
only the lower 36 bits (in 4.32 bit representation) are used. The actual
multiplier is defined in a special Xilinx unimacro, and there is a testbench
specifically for the multiplier
([`sim/mult_macro_tb.vhd`](sim/mult_macro_tb.vhd)). The testbench uses the
multiplier with 18x18 bits.

The testbench is self-checking, but it is only a quick check, not an exhaustive
one. It checks that the latency is exactly one clock cycle, that the product is
correct for all four combinations of signs, for both small values and for large
values (including the extremes -2^17 and 2^17-1), and that reset clears the
product.

The multiplier can be instantiated with a configurable number of clock cycles
of delay. A single clock cycle of delay is used for the time being. This may
have to be incremented if the clock frequency is increased.

Note that the simulation model of the multiplier ([`sim/mult_macro.vhd`](sim/mult_macro.vhd))
only supports a delay of one clock cycle. If the delay is changed, the model
must be extended too.

## Iterator
This component ([`src/iterator.vhd`](src/iterator.vhd)) performs the main
calculation. It takes as input the complex number c (or rather the real and
imaginary values cx and cy). It then iterates the Mandelbrot function a number
of times and stops when either the maximum iteration count is reached, or an
overflow occurs.

The testbench for the iterator ([`sim/iterator_tb.vhd`](sim/iterator_tb.vhd))
is self-checking, but it is not bit-accurate. It runs a few starting values (in
the set, escaping immediately, escaping quickly, and escaping slowly), and
compares the count with one calculated using real (floating point) numbers. The
counts must be equal, within a small tolerance. The script
[`sim/iterator_model.py`](sim/iterator_model.py) is a bit-accurate Python model
of the iterator, which follows the VHDL literally. It gives the same counts as
the testbench for the same points, and can be used to compare the iterator with
the real-number count for many more points (`./iterator_model.py --grid`).

The testbench includes two points where x+y or x-y is outside the range -2 to 2
during the iteration (see [Overflow](#overflow)). An earlier version of the
iterator, where these values wrapped around, gave a wrong count for both.

The complete picture can be checked bit-accurately too. The script
[`sim/model.py`](sim/model.py) is a vectorized (numpy) version of the same
model, which calculates the count for every pixel of the initial view, using
the same values of c as the design. Run as a script, it compares the model with
a calculation using real numbers. The testbench
[`sim/main_tb.vhd`](sim/main_tb.vhd) runs `main.vhd` with the initial view, and
writes every write to the display memory to the file `sim/main_out.txt`. The
script [`sim/cmp_rtl.py`](sim/cmp_rtl.py) then compares these values with the
model. A complete picture takes several hours to simulate, but a partial picture
can be compared too:
```
make run TB=main STOP_TIME=700us
sim/cmp_rtl.py
```
The 700 us of simulated time (about 13 minutes) gives more than 50000 pixels,
from all 240 column modules. This testbench is not part of `make sim`.

The iterator has been heavily optimized to use only a single multiplier, and to
pipeline the calculations. Each iteration takes three clock cycles, and is
controlled by a simple state machine:
* In the first clock cycle (ADD\_ST), the multiplier is given the values of x
  and y, and simultaneously, the values x+y and x-y are calculated (in 19
  bits).
* In the second clock cycle (MULT\_ST), the multiplier is given the values of
  (x+y) and (x-y), and the output from x\*y is stored in registers.
* In the third clock cycle (UPDATE\_ST), the new values of x and y are
  calculated. The above three steps are repeated until a maximum loop count or
  until an overflow happens.

The inputs to this block are: start\_i, cx\_i, and cy\_i. Outputs are done\_o
and cnt\_o. The values of cx\_i and cy\_i must be held constant for the entire
calculation. The signal start\_i is pulsed high for a single clock cycle. The
signal done\_o goes high when the calculation is finished, and stays high, with
cnt\_o unchanged, until the next start\_i.

Example: We start with the point -1+0.5i, i.e. cx = -1 and cy = 0.5. The
expected sequence of points is then:
```
cnt |   x           |   y
----+---------------+---------------
 0  |  0    (00000) |  0    (00000)
 1  | -1    (30000) |  0.5  (08000)
 2  | -0.25 (3C000) | -0.5  (38000)
 3  | -1.19 (2D000) |  0.75 (0C000)
 4  | -0.15 (3D900) | -1.28 (2B800)
```
The values in the parentheses are the (2.16 fixed point) hexadecimal
representation of the real numbers.

### Overflow
The iteration stops when the new value of x or y is outside the range -2 to 2
(not including 2), which is the range of the 2.16 number format. For points
that are not in the Mandelbrot set, the values grow quickly once they get out
of this range.

The two products are calculated in 4.32 format (36 bits), and the new values
are the sums
```
new_x   = (x+y)*(x-y) + cx
new_y/2 = x*y + cy/2
```
also in 4.32 format. The range is checked on these sums, and not on the
products alone. A product can be between -4 and 4, i.e. outside the range of
the final value, even when the sum with cx or cy/2 is inside the range, and the
other way around. The sums are between -6 and 6, so they can not overflow
the 36 bits. The new x is in range if the three top bits of the sum are equal.
The new y is twice the second sum, so that is in range if the four top bits of
the second sum are equal. The new values of x and y are then bits 33 to 16 of
the first sum and bits 32 to 15 of the second sum, respectively.

The count returned in cnt\_o is the number of the first iteration where the
value is out of range, or the maximum count if this does not happen.

The value 2 itself is outside the range. So the point $c = -2$, which is in
the Mandelbrot set ($z$ is -2, 2, 2, 2, ...), gets the count 2, as if it was
outside the set. Points very close to -2 are not affected (e.g. for
$c = -2 + 2^{-16}$, $z_2$ is $2 - 3 \cdot 2^{-16}$, which is in range). This is
only a single point, so it does not matter for the picture.

The values x+y and x-y, which are the inputs to the multiplier in the second
clock cycle, are between -4 and 4, so they need 19 bits (3.16 format). The
second input of the multiplier (the B port of the DSP) has only 18 bits.
However, at most one of x+y and x-y is outside the range -2 to 2:
* If x and y have the same sign bit, then x-y is in the range -2 to 2.
* Otherwise, x+y is in the range -2 to 2.

So the one of them that may be out of range is given to the first input of the
multiplier, which has 19 bits, and the other one to the second input, which has
18 bits. The choice only depends on the sign bits of x and y, so it does not
have to wait for the additions.

An earlier version of the iterator calculated x+y and x-y in 18 bits, so they
wrapped around when they were outside the range -2 to 2. For the initial view
this gave a different count for about 13% of the pixels, compared with the
same calculation without the wrap around. It was much worse when zooming in
near the points -2 and +-i, where the orbits often have x+y or x-y close to
-2 or 2. Here the picture had straight edges and broken filaments, and some
points were even wrongly shown as inside or outside the set.

The remaining differences, compared with a calculation using real numbers, come
from the limited precision of the 2.16 format. For the initial view about 1.5%
of the pixels have a different count, and about 0.1% (292 pixels) are on the
other side of the boundary of the set (`sim/model.py`).

TODO: The DSP contains an adder (as well as the multiplier). Perhaps it is
possible to use this built-in adder and thereby save logic resources. This may
perhaps improve the timing slightly. However, overflow detection needs to be
rewritten then.

## Columns
The following terms are used in this document:
* A *picture column* is a vertical slice of the picture. Calculating one picture
  column is one job.
* A *column module* is an instance of [`src/column.vhd`](src/column.vhd). It
  calculates one picture column at a time, row by row, using one iterator.
* An *iterator* is the block in [`src/iterator.vhd`](src/iterator.vhd). It
  calculates the count for a single point.

There is one iterator, and therefore one DSP, in each column module, and there
are `G_NUM_ITERATORS` column modules (240 in the design). The generics keep
their names: `G_NUM_COLS` is the number of picture columns, and
`G_NUM_ITERATORS` is the number of column modules.

The final picture is sliced into vertical picture columns, and each picture
column is calculated in its entirety by a column module.

The inputs to a column module are:
```
job_start_i  : in  std_logic;
job_cx_i     : in  std_logic_vector(17 downto 0);
job_starty_i : in  std_logic_vector(17 downto 0);
job_stepy_i  : in  std_logic_vector(17 downto 0);
```
and the output is:
```
job_busy_o   : out std_logic;
```
The signal job\_start\_i is pulsed high for one clock cycle to initiate the
calculation of an entire picture column, and the output job\_busy\_o remains high
until the entire calculation is finished.

The results of the calculation are presented on the following output ports:
```
res_addr_o   : out std_logic_vector( 8 downto 0);
res_data_o   : out std_logic_vector( 8 downto 0);
res_valid_o  : out std_logic
```
with the additional input port
```
res_ack_i    : in  std_logic;
```
The res\_addr\_o is the current row number, and res\_data\_o is the calculated
count value for this pixel. The res\_ack\_i is needed, because there may be an
arbitrarily long delay before the job dispatcher has time to acknowledge the
result.

The testbench for the column module ([`sim/column_tb.vhd`](sim/column_tb.vhd))
is self-checking. It runs two jobs of ten rows each, and checks that the column
module is busy only during a job, that the results come in order, that a result stays
unchanged until it is acknowledged (the acknowledge is delayed by a varying
number of clock cycles), and that the count for each row is close to the count
calculated using real numbers.

## Dispatcher
This ([`src/dispatcher.vhd`](src/dispatcher.vhd)) is essentially the top level
entity controlling the calculation of the entire picture. This is perhaps the
most complicated module. The input signals are:
```
start_i   : in  std_logic;
startx_i  : in  std_logic_vector(17 downto 0);
starty_i  : in  std_logic_vector(17 downto 0);
stepx_i   : in  std_logic_vector(17 downto 0);
stepy_i   : in  std_logic_vector(17 downto 0);
```
and the output is:
```
done_o    : out std_logic
```
The signal start\_i is pulsed high for one clock cycle to initiate the
calculation. The signal done\_o goes high when the calculation is finished, and
stays high until the next start\_i. Three additional output signals go to the
display memory:
```
wr_addr_o : out std_logic_vector(18 downto 0);
wr_data_o : out std_logic_vector( 8 downto 0);
wr_en_o   : out std_logic;
```

This module instantiates a configurable number of column modules (ideally 240
instances, one for each DSP). It keeps track of which column modules are
currently calculating, and whenever a column module is idle, a new job (the next
picture column) is sent to it.

A separate scheduler module is used to send jobs to the different column
modules. Currently, the scheduler operates in a round-robin fashion. This
potentially may give a delay up to 240 clock cycles before an idle column module
is given a job. With 640 jobs, the maximum delay is about 1.1 ms, assuming the
column modules operate at 140.625 MHz. This delay is negligible.

The dispatcher has a self-checking testbench
([`sim/dispatcher_tb.vhd`](sim/dispatcher_tb.vhd)). It calculates two small
pictures (64 by 16 pixels, with 16 column modules), one right after the other,
and checks that each pixel is written exactly once, that everything has been
written when done\_o goes high, that done\_o goes low when a new picture is
started, and that the value of each pixel is close to the count calculated
using real numbers. It then repeats this for two pictures with a single picture
column, i.e. with fewer picture columns than column modules, which is a special
case for done\_o. The simulation takes about 10 seconds.

The scheduler has a small self-checking testbench
([`sim/scheduler_tb.vhd`](sim/scheduler_tb.vhd)). It checks that nothing is
started when the scheduler is not active or when everything is busy, that each
idle process is started once per round and busy processes never, that the
processes are started in round-robin order, and that reset restarts the
scheduler from the first process.

## The top level
The top level ([`src/mandelbrot.vhd`](src/mandelbrot.vhd)) connects the clock
generation, the dispatcher, the display memory and the VGA output, and handles
the buttons and switches.

**Reset.** The reset button is stretched to eight clock cycles, separately for
the main clock and for the VGA clock.

**Continuous calculation.** A new picture is started as soon as the previous one
is finished. When the signal done\_o from the dispatcher goes high, the signal
active is cleared for one clock cycle, and then it is set again together with a
pulse on start. The dispatcher clears done\_o when it sees the start, so done\_o
is ignored while start is high.

**The view.** The view is given by the position of the top left corner of the
picture (startx, starty), and the size of a pixel (stepx, stepy). The initial
view has the real axis from -1.6667 to 1.0 and the imaginary axis from -1.0 to
1.0, and the pixel size is the size of the view divided by the number of columns
and rows (640 and 480).

The view is controlled by the module [`src/view.vhd`](src/view.vhd). It is
updated at a fixed rate, which is given by a counter of 23 bits in `main.vhd`.
At 140.625 MHz this is once every 60 ms, i.e. about 17 times per second. At
each update, the following happens, depending on the buttons that are held
down:
* `BTNC`: Zoom. The values of stepx and stepy are both decreased by 1/64 of
  their value plus one least significant bit (zoom in), or increased by the same
  (zoom out, if switch 2 is on). This is about 1.6% per update. The values of
  startx and starty are not changed, so the zoom keeps the top left corner of
  the view fixed (except at the edge of the range, see below).
* `BTNL`, `BTNR`: startx is decreased or increased by stepx (`BTNR` has
  priority if both are held down).
* `BTNU`, `BTND`: starty is decreased or increased by stepy (`BTND` has
  priority if both are held down).

The view is always kept inside the range of the 2.16 number format, i.e. -2 to
2 (not including 2). Otherwise the values of cx and cy, which the dispatcher and
the column modules calculate by adding stepx and stepy, would wrap around, and
the picture would show parts of the range twice (e.g. a second copy of the set
at the right edge). Similarly, the size of a pixel must not become zero or
negative. So:
* Panning stops when the first column (row) is at -2, or when the last column
  (row) is at 2 minus one LSB.
* Zooming in stops when the size of a pixel is one LSB (2^-16), i.e. the
  picture is 0.0098 wide. In practice the picture is limited by the precision
  of the calculation before this.
* When zooming out would move the last column (row) beyond the range, the view
  is moved left (up) instead, so the last column (row) stays at the end of the
  range. Zooming out stops when the view can not get any larger, i.e. when it
  covers almost the whole range from -2 to 2 in x.

The check that the zoomed view fits is a comparison of the new size of a pixel
with a constant, the largest size for which the view fits. The position of the
right (bottom) edge needs the size of a pixel multiplied by the number of
columns (rows) minus one. This is done serially with shifts and subtractions,
one bit of the constant per clock cycle, so no DSP is used. Doing all of the
update in a single clock cycle would be far too slow for the MAIN clock, so
the update is done in small steps over 15 clock cycles, with at most one
addition or comparison per step. The outputs are all changed at the end of the
update. The new view is used when the next picture is started.

The view control has a self-checking testbench
([`sim/view_tb.vhd`](sim/view_tb.vhd)). It holds the buttons down for many
updates, and checks after every update that the view is inside the range, that
the size of a pixel is at least one LSB, that the view is the one expected
from a simple model, and that the outputs all change in the same clock cycle.
It also checks that panning and zooming reach the ends of the range and stop
there, and that a pulse on upd\_i during an update (which takes 15 clock
cycles) is ignored, but one just after the update is not. The initial view is
checked when the design is elaborated: it must be inside the range too.

**The LEDs.** If switch 1 is on, the LEDs show bits 26 to 11 of a counter. This
counter counts clock cycles while a picture is being calculated, and it is
cleared when the next picture is started. A single step on the LEDs is therefore
2^11 clock cycles, which is 14.56 us, and the value wraps around after 0.95
seconds. If switch 1 is off, the LEDs show the sum of the wait counters of all
the column modules. The wait counter of a column module counts the clock cycles
that the module has to wait for its result to be accepted, in the same unit of
2^11 clock cycles. It is only cleared by reset, so it accumulates over many
pictures. The sum is 16 bits wide, so it wraps around.

**Other inputs.** The switches 0 and 3 to 7 are not used.

## Timing
Counters measure the total time it takes to generate the picture as well as the
total amount of time the iterators are waiting to write to display memory (see
[The top level](#the-top-level)).

The numbers measured on the board were:
* The total time for the picture: 472\*2^11 clock cycles, which at 140.625 MHz
  is 6.9 ms.
* The waiting time of all the column modules: 28642\*2^11 clock cycles in
  total, i.e. 1.7 ms for each column module. So about a quarter of the time is
  spent waiting.

These were measured with an earlier version of the iterator, which did not
detect all overflows, and which calculated x+y and x-y in 18 bits (see
[Overflow](#overflow)), and with a main clock of 150 MHz (the times above have
been recalculated for 140.625 MHz). They have not been measured on the board
again since then.

The time for the current design can be estimated with the model
[`sim/model.py`](sim/model.py), which gives the same number of clock cycles,
472\*2^11, for the picture. The reason is the following. A column module uses
3 clock cycles per iteration, plus 7 clock cycles to start the iterator and to
deliver the result (4 for the points that reach the maximum count). Then the
result must be accepted by the dispatcher. The round-robin scheduler for the
results (i\_scheduler\_res) checks each column module once every 240 clock
cycles, so the time from one result of a column module to the next is always a
multiple of 240 clock cycles. This has been checked in simulation. So:
* A pixel with a count up to 77 takes 240 clock cycles, i.e. the iterator is
  idle for most of the time, waiting for the result to be accepted.
* A pixel in the set (count 511) takes 3\*511+4 = 1537 clock cycles, which is
  rounded up to 1680 clock cycles.

For the initial view the average count is 151, so the iterator needs 460 clock
cycles per pixel on average, but each pixel takes 652 clock cycles on average,
including the waiting. The total waiting time of all the column modules is then
28896\*2^11 clock cycles, which agrees with the 28642\*2^11 clock cycles
measured on the board. The picture is finished when the last column module is
finished. A single picture column through the middle of the set takes up to
0.73 million clock cycles (5.2 ms), so these picture columns decide the total
time. Without the waiting, the picture would take about 4.2 ms (if the work
was spread evenly over the column modules).

This could be improved by accepting a result as soon as it is ready, e.g.
with a priority encoder ([`src/priority_pipeline.vhd`](src/priority_pipeline.vhd)
is a pipelined version of one) instead of the round-robin scheduler, or by
storing a few results in each column module, so the iterator can continue with
the next row while it waits. At this speed (about 145 pictures per second) it
does not matter much, though.

## Resources and timing closure
The numbers below come from a successful run of `make vivado` (Vivado 2025.1,
part xc7a100tcsg324-1, i.e. speed grade -1), which meets timing with a
140.625 MHz main clock.

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 240      | 240       | 100
| Block RAM        | 128 RAMB36 + 1 RAMB18 | 135 RAMB36 | about 95
| LUTs             | about 61,900 (cells) | 63,400 | about 98
| Registers        | about 53,800 | 126,800 | about 42
| Clock buffers    | 3 BUFG, 1 MMCM | |

The resource numbers are the cell counts after synthesis (the "Report Cell
Usage" table in `vivado.log`), and the available numbers are the totals for
the XC7A100T. The LUTs are the sum of the LUT1 to LUT6 cells (61,875). This is
the number of LUT cells, not the number of LUTs in the device that are used,
which can be smaller, because two small LUT cells can share one LUT (which the
placer does, e.g. "LUT Combining" in `phys_opt_design`). The exact numbers are
given by `report_utilization` on the routed design. The registers are the FDRE
and FDSE cells (53,832).

Before the iterator was changed to give x+y or x-y to the multiplier with 19
bits (see [Overflow](#overflow)), and before the limits for pan and zoom were
added to the view control (see [The top level](#the-top-level)), the design
used about 52,000 LUT cells and 53,300 registers. Most of the increase is
probably in the iterators, because there are 240 of them.

The design uses memory with 2^19 entries of 8 bit (the lowest 8 bits of the
count), i.e. 128 blocks of 36 kbit BRAM (each with 32 kbit of data), as
expected.

The timing after routing is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.008 ns (TNS 0)
| Hold (WHS)  | +0.029 ns (THS 0)

These are the values from `vivado.log`: the hold slack from the end of
`route_design`, and the setup slack from the post-route `phys_opt_design`.

The timing is met for all clocks. The 140.625 MHz main clock (period 7.11 ns)
is generated from the 100 MHz input clock by the MMCM (multiplied by 11.25 and
divided by 8), and the only constraint in `mandelbrot.xdc` is the 100 MHz input
clock. The MMCM also generates the 25 MHz VGA clock (divided by 45).

The slack is small, so the design is close to the limit of what this device and
this flow can achieve. In an earlier run (before the latest changes), the
critical paths were in the dispatcher: the selection
of the column module in the schedulers (`job_idx_valid` and the `job_busy_o`
signals from the column modules), and the registers for the write address and
data going to the display memory (`wr_addr_r` and `wr_data_r`). The directives used in
`mandelbrot.tcl` matter:
* `synth_design` with `-directive AreaOptimized_medium`
* `opt_design` with `-directive ExploreWithRemap`
* `phys_opt_design` with `-directive AlternateFlowWithRetiming`, both after
  placement and after routing

The main clock was originally 150 MHz. The design with the earlier version of
the iterator met timing at that frequency (setup slack +0.047 ns). After the
overflow detection in the iterator was improved (see [Overflow](#overflow)),
which uses more logic (about 1,400 more LUTs), the design no longer met timing
at 150 MHz (setup slack -0.055 ns, with the critical paths in the dispatcher),
and the main clock was lowered to 140.625 MHz. A possible improvement is to
pipeline the selection of the column module in the scheduler, e.g. by dividing
the column modules into 16 groups of 16, which should allow a higher clock
frequency.
This has not been tried.

The complete run of `make vivado` takes about 11 minutes (synthesis about 3.5
minutes, placement about 3 minutes, routing about 3 minutes), on a machine with
8 threads.

All 240 DSPs running at 140.625 MHz gives a peak of 34 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 22 billion multiplications per second.
