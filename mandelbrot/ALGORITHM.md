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
mandelbrot                      src/mandelbrot.vhd (top level, clocks and resets)
 +- clk                         src/clk.vhd (MMCM and clock buffers)
 +- main                        src/main.vhd (everything in the MAIN clock domain)
 |   +- view                    src/view.vhd (view control from the buttons)
 |   +- dispatcher              src/dispatcher.vhd
 |       +- scheduler           (i_scheduler, selects the column module to receive a job)
 |       +- column  (x 240)     src/column.vhd (the column modules)
 |       |   +- iterator        src/iterator.vhd
 |       |       +- mult_macro  (Xilinx unimacro, uses one DSP)
 |       +- scheduler           (i_scheduler_res, selects the column module whose result is accepted)
 +- disp_mem                    src/disp_mem.vhd (display memory, between the two clock domains)
 +- vga                         src/vga.vhd (everything in the VGA clock domain)
     +- pix                     src/pix.vhd (pixel counters)
     +- disp                    src/disp.vhd (VGA output)
```
The number of column modules (and therefore iterators and DSPs) is set by the
generic `G_NUM_ITERATORS`, which `main` sets to 240.

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

The same bit-accurate model is also written in VHDL, in the package
[`sim/iterator_model_pkg.vhd`](sim/iterator_model_pkg.vhd). The testbenches for
the column module and the dispatcher compare every count with this model, and
require them to be equal. The iterator testbench still compares with real
numbers, so that it also checks that the model (i.e. the design) calculates the
Mandelbrot iteration.

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

Finally, there is a debug output:
```
wait_cnt_o   : out std_logic_vector(15 downto 0);
```
This is the number of clock cycles the column module has spent waiting for a
result to be acknowledged, in units of 2^11 clock cycles. It is only cleared
by reset.

The testbench for the column module ([`sim/column_tb.vhd`](sim/column_tb.vhd))
is self-checking. It runs three jobs of ten rows each, and checks that the
column module is busy only during a job, that the results come in order, that a
result stays unchanged until it is acknowledged (the acknowledge is delayed by a
varying number of clock cycles), and that the count for each row is exactly the
count calculated by the bit-accurate model (see [Iterator](#iterator)). The
third job is near the top of the set, where x+y or x-y is often out of range.

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
The data is the 9-bit count. Only the lower 8 bits are stored in the display
memory, see [The top level](#the-top-level). Finally, there is a debug output:
```
wait_cnt_tot_o : out std_logic_vector(15 downto 0);
```
This is the sum of the wait\_cnt\_o outputs of all the column modules.

This module instantiates a configurable number of column modules (ideally 240
instances, one for each DSP). It keeps track of which column modules are
currently calculating, and whenever a column module is idle, a new job (the next
picture column) is sent to it.

A separate scheduler module is used to send jobs to the different column
modules. Currently, the scheduler operates in a round-robin fashion. This
potentially may give a delay up to 240 clock cycles before an idle column module
is given a job, i.e. 1.7 us at 140.625 MHz. The column modules wait in
parallel, and with 640 jobs and 240 column modules, each column module gets
fewer than three jobs on average. So the delay adds only a few microseconds to
the time for a picture, which is about 7 ms. This delay is negligible.

The dispatcher has a self-checking testbench
([`sim/dispatcher_tb.vhd`](sim/dispatcher_tb.vhd)). It calculates two small
pictures (64 by 16 pixels, with 16 column modules), one right after the other,
and checks that each pixel is written exactly once, that everything has been
written when done\_o goes high, that done\_o goes low when a new picture is
started, and that the value of each pixel is exactly the count calculated by
the bit-accurate model (see [Iterator](#iterator)) for the value of c of that
pixel. This also checks that each result is written to the right address. It
then repeats this for two pictures with a single picture
column, i.e. with fewer picture columns than column modules, which is a special
case for done\_o. The simulation takes about 10 seconds.

The scheduler has a small self-checking testbench
([`sim/scheduler_tb.vhd`](sim/scheduler_tb.vhd)). It checks that nothing is
started when the scheduler is not active or when everything is busy, that each
idle process is started once per round and busy processes never, that the
processes are started in round-robin order, and that reset restarts the
scheduler from the first process.

## The top level
The top level ([`src/mandelbrot.vhd`](src/mandelbrot.vhd)) instantiates the
clock generation and the display memory, generates the resets, and splits the
rest of the design into one module for each clock domain:
* [`src/main.vhd`](src/main.vhd) runs in the MAIN clock domain (140.625 MHz).
  It handles the buttons and switches, controls the dispatcher, writes the
  results to the display memory, and drives the LEDs.
* [`src/vga.vhd`](src/vga.vhd) runs in the VGA clock domain (25 MHz). It
  generates the pixel counters, reads the display memory, and generates the VGA
  output.

The two clock domains communicate only through the display memory, which has
a write port in the MAIN clock domain and a read port in the VGA clock domain.

**Reset.** The design is held in reset while the reset button is pressed, and
while the MMCM is not locked. This signal is synchronized to each clock domain
(the main clock and the VGA clock), and the reset is then stretched to eight
clock cycles after it is released. The VGA reset is connected to the `vga`
module and to the read port of the display memory, but neither of them uses it
at present.

**The display memory.** The display memory
([`src/disp_mem.vhd`](src/disp_mem.vhd)) has 2^19 entries of 8 bits. The
address is the picture column (10 bits) followed by the row (9 bits). The
dispatcher delivers a 9-bit count for each pixel, but `main` only writes the
lower 8 bits. The `vga` module uses these 8 bits directly as the colour, in the
format RRRGGGBB. So the colours repeat for counts from 256 to 511, and the
points in the set (count 511) are white.

The rest of this section describes `main`.

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
  (zoom out, if switch 2 is on). This is about 1.6% per update. The zoom keeps
  the centre of the picture fixed: startx is moved by the change of stepx
  times 320 (half the number of columns), and starty by the change of stepy
  times 240, so the pixel in column 320 and row 240 (just right of and below
  the centre of the screen) shows the same point before and after the zoom
  (except at the edge of the range, see below).
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
* When zooming out would move the first column (row) to before -2, or the
  last column (row) beyond the range, the view is moved right (down) or left
  (up) instead, so that edge stays at the end of the range. Zooming out stops
  when the view can not get any larger, i.e. when it covers almost the whole
  range from -2 to 2 in x.

The check that the zoomed view fits is a comparison of the new size of a pixel
with a constant, the largest size for which the view fits. The position of the
right (bottom) edge needs the size of a pixel multiplied by the number of
columns (rows) minus one, and keeping the centre fixed needs the change of the
size multiplied by 320 (240). These multiplications are done serially with
shifts and additions or subtractions, one bit of the constant per clock cycle,
so no DSP is used. Doing all of the update in a single clock cycle would be far
too slow for the MAIN clock, so the update is done in small steps over 17 clock
cycles, with at most one addition or comparison per step. The outputs are all
changed at the end of the update. The new view is used when the next picture is
started.

The view control has a self-checking testbench
([`sim/view_tb.vhd`](sim/view_tb.vhd)). It holds the buttons down for many
updates, and checks after every update that the view is inside the range, that
the size of a pixel is at least one LSB, that the view is the one expected
from a simple model, and that the outputs all change in the same clock cycle.
It also checks that panning and zooming reach the ends of the range and stop
there, that zooming in keeps the centre exactly fixed, and that a pulse on
upd\_i during an update (which takes 17 clock cycles) is ignored, but one just
after the update is not. The initial view is checked when the design is
elaborated: it must be inside the range too.

**The LEDs.** The LEDs show one of two values, for the most recently finished
picture, or averaged over the last 64 pictures. The values are latched at the
end of a picture, because the picture is recalculated continuously (about
every 7 ms), so the counters themselves change too fast to be read.
* If switch 1 is on, the LEDs show the time taken by the picture. A counter
  counts clock cycles while a picture is being calculated, and it is cleared
  when the next picture is started. At the end of the picture, bits 26 to 11
  of the counter are latched. A single step on the LEDs is therefore 2^11 clock
  cycles, which is 14.56 us, and the value wraps around after 0.95 seconds.
* If switch 1 is off, the LEDs show the total waiting time of all the column
  modules during a picture, averaged over 64 pictures (about 0.44 seconds for
  the initial view). The wait counter of a column module counts the
  clock cycles that the module has to wait for its result to be accepted, in
  the same unit of 2^11 clock cycles. The wait counters are only cleared by
  reset, and the dispatcher adds them up (wait\_cnt\_tot\_o). So `main`
  calculates the waiting time of a picture as the difference between the sum
  at the end of this picture and the sum at the end of the previous picture.
  The sum is 16 bits wide, and the difference is calculated modulo 2^16, so it
  is correct even when the sum wraps around. The differences of 64 pictures
  are added up, and the LEDs show the sum divided by 64 (the constant
  C\_AVG\_LOG2 in `main.vhd` is 6). The LEDs are updated after every 64
  pictures, which takes longer when each picture takes longer, e.g. when
  zooming into the set.

  The averaging is needed because each wait counter is truncated to units of
  2^11 clock cycles before the sum. So the waiting time of a column module
  during a single picture may be one unit too high or too low, depending on
  the part of the counter below 2^11 at the start and at the end of the
  picture. The waiting time of a single picture can therefore differ by up to
  about 240 (the number of column modules) from the exact value, and it
  changes from picture to picture, even when the pictures are the same, so the
  lower bits would blink. These errors cancel between consecutive pictures, so
  the error of the sum over 64 pictures is also at most about 240, and the
  error of the average is at most about 4.

**Other inputs.** The switches 0 and 3 to 7 are not used.

## Timing
Counters measure the total time it takes to generate the picture as well as the
total amount of time the iterators are waiting to write to display memory. The
values are shown on the LEDs, see [The top level](#the-top-level).

The numbers measured on the board, with the current design and the initial
view, are:
* The time for the picture (switch 1 on): 0x01D8 = 472, i.e. 472\*2^11 clock
  cycles, which at 140.625 MHz is 6.9 ms (about 145 pictures per second). This
  value is steady.
* The waiting time of all the column modules (switch 1 off): about
  0x721F = 29215, i.e. 29215\*2^11 clock cycles in total, which is 1.8 ms for
  each column module, or about a quarter of the time. This was measured before
  the value was averaged over 64 pictures, so the lowest bits changed from
  picture to picture, because of the truncation of the wait counters (see
  [The top level](#the-top-level)).

Both values agree with the model [`sim/model.py`](sim/model.py), which
estimates the time for the picture from the count of each pixel, as follows.
A column module uses 3 clock cycles per iteration, plus 7
clock cycles to start the iterator and to deliver the result (4 for the points
that reach the maximum count). Then the result must be accepted by the
dispatcher. The round-robin scheduler for the results (i\_scheduler\_res)
checks each column module once every 240 clock cycles, so the time from one
result of a column module to the next is always a multiple of 240 clock
cycles. This has been checked in simulation. So:
* A pixel with a count up to 77 takes 240 clock cycles, i.e. the iterator is
  idle for most of the time, waiting for the result to be accepted.
* A pixel in the set (count 511) takes 3\*511+4 = 1537 clock cycles, which is
  rounded up to 1680 clock cycles.

For the initial view the average count is 151, so the iterator needs 460 clock
cycles per pixel on average, but each pixel takes 652 clock cycles on average,
including the waiting. The picture is finished when the last column module is
finished. A single picture column through the middle of the set takes up to
0.73 million clock cycles (5.2 ms), so these picture columns decide the total
time. The model gives 472\*2^11 clock cycles for the picture, the same as
measured.

The model gives a total waiting time of 28896\*2^11 clock cycles, i.e. 192
clock cycles per pixel on average. The wait counter of a column module counts 2
clock cycles more for each pixel: it counts from 3 clock cycles after the
result is ready until the clock cycle before the acknowledge reaches the column
module. With these 2 clock cycles for each of the 307200 pixels, the expected
value on the LEDs is 29196 (0x720C), which agrees with the measured value
within 0.1%. Without the waiting, the picture would take about 4.2 ms (if the
work was spread evenly over the column modules).

Similar values (472\*2^11 clock cycles for the picture, and 28642\*2^11 clock
cycles of waiting) were measured earlier, with an iterator which did not detect
all overflows and which calculated x+y and x-y in 18 bits (see
[Overflow](#overflow)), and with a main clock of 150 MHz. The time for the
picture did not change, because it is decided by the picture columns through
the middle of the set, where most of the pixels reach the maximum count.

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
| Slices           | 15,402   | 15,850    | 97
| LUTs             | 49,087   | 63,400    | 77
| Registers        | 53,960   | 126,800   | 43
| Clock buffers    | 3 BUFG, 1 MMCM | |

The resource numbers are from `report_utilization` on the routed design
(`mandelbrot.dcp`), and the available numbers are the totals for the XC7A100T.
Almost all the slices are used, so the design is nearly full, even though only
77% of the LUTs are used.

The "Report Cell Usage" table in `vivado.log` gives the cell counts after
synthesis instead: 61,895 LUT cells (LUT1 to LUT6) and 53,885 registers (FDRE
and FDSE cells). The number of LUT cells is larger than the number of LUTs
used, because two small LUT cells can share one LUT (the placer does this, e.g.
"LUT Combining" in `phys_opt_design`). Before the iterator was changed to give
x+y or x-y to the multiplier with 19 bits (see [Overflow](#overflow)), and
before the limits for pan and zoom were added to the view control (see
[The top level](#the-top-level)), the design used about 52,000 LUT cells and
53,300 registers. Most of the increase is probably in the iterators, because
there are 240 of them.

The display memory has 2^19 entries of 8 bits (the lowest 8 bits of the
count), i.e. 128 blocks of 36 kbit BRAM (each with 32 kbit of data), as
expected. The single RAMB18 is used by the dispatcher, for the table
`job_addr_r` that holds the picture column of each column module (240 entries
of 10 bits).

The timing after routing is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.116 ns (TNS 0)
| Hold (WHS)  | +0.026 ns (THS 0)

These are the values from `report_timing_summary` on the routed design
(`mandelbrot.dcp`), after the post-route `phys_opt_design`.

The timing is met for all clocks. The 140.625 MHz main clock (period 7.11 ns)
is generated from the 100 MHz input clock by the MMCM (multiplied by 11.25 and
divided by 8), and the only constraint in `mandelbrot.xdc` is the 100 MHz input
clock. The MMCM also generates the 25 MHz VGA clock (divided by 45).

The slack is small, so the design is close to the limit of what this device and
this flow can achieve. The critical paths are in the dispatcher, in the
selection of the column module whose result is accepted: from `res_busy_r`
(one bit for each of the 240 column modules) through the scheduler
`i_scheduler_res`, which picks one of the 240 bits, to the clock enable of
`job_idx_start_r`. This path has 6 levels of logic (3 LUT6, 2 MUXF7 and 1
MUXF8), and more than 70% of the delay is routing. In earlier runs, the
critical paths were also in the schedulers, and in the registers for the write
address and data going to the display memory (`wr_addr_r` and `wr_data_r`).
The directives used in `mandelbrot.tcl` matter:
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
the column modules into 15 groups of 16, which should allow a higher clock
frequency.
This has not been tried.

The complete run of `make vivado` takes about 8.5 minutes (synthesis about 2.5
minutes, placement about 2 minutes, routing about 2.5 minutes), on a machine
with 8 threads.

All 240 DSPs running at 140.625 MHz gives a peak of 34 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 22 billion multiplications per second.
