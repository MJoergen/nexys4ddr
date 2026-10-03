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
 |       |       +- (DSP48E1)   (inferred in p_dsp, multiplier and adder)
 |       +- scheduler           (i_scheduler_res, selects the column module whose result is accepted)
 +- disp_mem                    src/disp_mem.vhd (display memory, between the two clock domains)
 +- vga                         src/vga.vhd (everything in the VGA clock domain)
     +- pix                     src/pix.vhd (pixel counters)
     +- disp                    src/disp.vhd (VGA output, uses the palettes in src/palette_pkg.vhd)
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
The built-in DSP (DSP48E1) provides a 25x18-bit signed multiplier, followed by
a 48-bit adder (the post-adder). The iterator uses it as a 19x18-bit
multiplier, with the first input in 3.16 bit representation and the second
input in 2.16 bit representation (see [Overflow](#overflow) for why the first
input has 19 bits). This generates a 37-bit result in 5.32 bit representation.
The products in the iterator are always between -4 and 4, so only the lower 36
bits (in 4.32 bit representation) are used. The post-adder then adds cx or cy/2
to the product (see [Iterator](#iterator)), so the output of the DSP is the new
value of x or half the new value of y.

The DSP is not instantiated directly. It is inferred by Vivado from the process
`p_dsp` and the addition after it in [`src/iterator.vhd`](src/iterator.vhd), so
the simulation needs no model of the DSP. The inputs of the multiplier (a\_r
and b\_r), the constant (c\_r), and the product are all registered, and Vivado
moves these registers into the DSP (the registers A, B, C, and M). The sum is
not registered (the register P is not used), so the product is ready one clock
cycle after the inputs, and the sum in the same clock cycle. The "DSP Final
Report" in `vivado.log` shows how the DSP is used (`C'+(A'*B')'`).

An earlier version used the Xilinx macro `mult_macro` for the multiplier, and
added cx and cy/2 in the FPGA fabric. Using the post-adder instead saves about
9,400 LUTs and 14,100 registers (most of these are the registers a\_r, b\_r,
and c\_r, which are now in the DSP), and the paths through the iterator are no
longer close to being critical (see
[Resources and timing closure](#resources-and-timing-closure)).

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
  (x+y) and (x-y). The output of the DSP is x\*y + cy/2, which gives the new
  value of y.
* In the third clock cycle (UPDATE\_ST), the output of the DSP is
  (x+y)\*(x-y) + cx, which gives the new value of x. The above three steps are
  repeated until a maximum loop count or until an overflow happens.

The DSP adds cx or cy/2 to the product in its adder (see [Multiplier](#multiplier)),
so the constant is changed every clock cycle: cy/2 in MULT\_ST and cx in
UPDATE\_ST.

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
also in 4.32 format. The sums are calculated by the adder in the DSP. The
range is checked on these sums, and not on the
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
by reset. The counter is only there when the generic G\_WAIT\_STAT
is true (the default is false). Otherwise wait\_cnt\_o is always zero, which
saves a 27-bit counter in each of the 240 column modules.

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
The data is the 9-bit count, which is stored in the display memory, see
[The top level](#the-top-level). Finally, there is a debug output:
```
wait_cnt_tot_o : out std_logic_vector(15 downto 0);
```
This is the sum of the wait\_cnt\_o outputs of all the column modules. Like
in the column module, it is only calculated when the generic G\_WAIT\_STAT is
true (the default is false), and the dispatcher passes G\_WAIT\_STAT on to the
column modules. The sum is calculated by a chain of 239 registered 16-bit
adders, so leaving it out saves both these and the counters in the column
modules. In the design, G\_WAIT\_STAT is set by the constant C\_WAIT\_STAT in
`main.vhd`.

This module instantiates a configurable number of column modules (ideally 240
instances, one for each DSP). It keeps track of which column modules are
currently calculating, and whenever a column module is idle, a new job (the next
picture column) is sent to it.

A separate scheduler module is used to send jobs to the different column
modules. Currently, the scheduler operates in a round-robin fashion. This
potentially may give a delay up to 240 clock cycles before an idle column module
is given a job, i.e. 1.4 us at 177.78 MHz. The column modules wait in
parallel, and with 640 jobs and 240 column modules, each column module gets
fewer than three jobs on average. So the delay adds only a few microseconds to
the time for a picture, which is about 5.4 ms. This delay is negligible.

The column modules are spread over the whole FPGA, so the signals that go from
the dispatcher to all of them have long routes. To keep each route shorter,
these signals go through an extra register in each group of 16 column modules
(the generic G\_GROUP\_SIZE, so there are 15 groups): the job (cx, starty, and
stepy), the start of the job, the reset, and the index of the column module
whose result is accepted. The registers of the groups are identical, so they
have the attribute `keep`, which prevents the synthesis tool from merging them.
Each column module registers the reset once more, so the reset register of a
group drives only 16 registers.

A result is accepted in three steps. First, the index of the column module
selected by i\_scheduler\_res goes to the register in each group. Then each
group acknowledges the selected column module, if it is in the group, and
selects its result. Finally, the result is selected from the group of the
column module and written to the display memory. The column module keeps its
result until it has seen the acknowledge, so the result is still there when
its group selects it. Because of the extra registers, the scheduler sees that
a column module is busy (with a job, or with a result that has been accepted)
four clock cycles after it has selected it, so the dispatcher needs at least
four column modules.

The dispatcher has a self-checking testbench
([`sim/dispatcher_tb.vhd`](sim/dispatcher_tb.vhd)). It calculates two small
pictures (64 by 16 pixels, with 16 column modules in groups of 5, so the last
group is smaller), one right after the other,
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
* [`src/main.vhd`](src/main.vhd) runs in the MAIN clock domain (177.78 MHz).
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
([`src/disp_mem.vhd`](src/disp_mem.vhd)) has 2^19 entries of 9 bits. The
address is the picture column (10 bits) followed by the row (9 bits). The
dispatcher delivers a 9-bit count for each pixel, and `main` writes all 9 bits.
The `vga` module converts the count to the colour, in the format RRRGGGBB, see
[Colours](#colours) below.

The memory is divided into 128 blocks of 2^12 entries, one BRAM each, selected
by the top 7 bits of the address. A 36 kbit BRAM holds 4096 entries of 9 bits
(the ninth bit is the parity bit of each byte), so the ninth bit needs no extra
BRAMs. The write address and data go to the blocks
through a tree of registers: first to a register in each of 16 groups of 8
blocks, and then to a register for each block, which can be placed next to its
BRAM. So no register drives more than 16 loads. A single register for the
address of all 128 BRAMs, which are spread over the whole FPGA, made the
routing too slow. The write port has three clock cycles of latency, and the
read port also three. The display memory has a small self-checking testbench
([`sim/disp_mem_tb.vhd`](sim/disp_mem_tb.vhd)). It writes to a few addresses
in each block, back-to-back both in different blocks and in the same block,
and reads them back on the read port. It checks that each value is written to
the right block and address, that a second write overwrites the first, that
nothing is written when the write enable is low, and that the read latency is
exactly three clock cycles.

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
At 177.78 MHz this is once every 47 ms, i.e. about 21 times per second. At
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
picture, or averaged over the last 64 pictures. The second value (the waiting
time) costs a lot of resources, so it is only there when C\_WAIT\_STAT is true,
and the default is false. Then the LEDs always show the first value (the time
for the picture), whatever switch 1 is. The values are latched at the
end of a picture, because the picture is recalculated continuously (about
every 5.4 ms), so the counters themselves change too fast to be read.
* If switch 1 is on, the LEDs show the time taken by the picture. A counter
  counts clock cycles while a picture is being calculated, and it is cleared
  when the next picture is started. At the end of the picture, bits 26 to 11
  of the counter are latched. A single step on the LEDs is therefore 2^11 clock
  cycles, which is 11.52 us, and the value wraps around after 0.75 seconds.
* If switch 1 is off, and the constant C\_WAIT\_STAT in `main.vhd` is true,
  the LEDs show the total waiting time of all the column modules during a
  picture, averaged over 64 pictures (about 0.35 seconds for
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

**Other inputs.** The switches 3 and 4 select the colour palette, see
[Colours](#colours). They are used in the VGA clock domain (in `vga`), not in
`main`. The switches 0 and 5 to 7 are not used.

## Colours
The display memory holds the count of each pixel (9 bits). The VGA output has
8 bits of colour, in the format RRRGGGBB (3 bits red, 3 bits green, and 2 bits
blue). The points in the set (count 511) get the colour of the set. For the
other counts, the lower 8 bits of the count (the value) are converted to the
colour by one of four palettes in [`src/palette_pkg.vhd`](src/palette_pkg.vhd),
selected by switches 3 and 4 (switch 4 is the high bit):
* 0: The value itself is the colour. Most of the pixels outside the set have
  small counts (in the initial view, 72% of all pixels have a count below 16),
  so only the blue and green bits are set, and red needs a count of at least
  32. The set is white (the same colour as the value 255).
* 1: Rainbow. The hue goes once around the colour circle (red, yellow, green,
  cyan, blue, magenta) for every 16 counts.
* 2: Fire. Black, red, orange, yellow, and white, with the square root of the
  value, once for the values 0 to 63, and again for 64 to 255.
* 3: Blue, white, orange, and dark brown, with the logarithm of the value, once
  for the values 0 to 6, again for 7 to 62, and again for 63 to 255.

In the palettes 1 to 3 the set is black. An earlier version stored only the
lower 8 bits of the count in the display memory, so the (few) points with the
count 255 had the same value as the set, and were shown in the colour of the
set. Storing all 9 bits costs no extra BRAMs (see
[The top level](#the-top-level)).

The palettes are tables of 256 entries, which are calculated from the formulas
above (with `ieee.math_real`) when the design is elaborated, so they are easy
to change. The colour of each entry is rounded to the nearest of the 8 (or 4)
levels of each colour component. The tables are implemented in LUTs, and the
lookup is done in the output register of `disp`, so it adds no delay.

The switches are asynchronous to the VGA clock, so they are synchronized with
two registers in `vga`.

The testbench for the VGA output ([`sim/vga_tb.vhd`](sim/vga_tb.vhd)) checks
the timing of the sync signals, and then the colour of every pixel of a frame,
with a different value for each pixel, and a different palette in each quarter
of the frame.

## Timing
Counters measure the total time it takes to generate the picture as well as the
total amount of time the iterators are waiting to write to display memory. The
second one must be enabled with C\_WAIT\_STAT in `main.vhd`, see
[The top level](#the-top-level). The
values are shown on the LEDs, see [The top level](#the-top-level).

The numbers measured on the board, with the main clock at 174.55 MHz, the
waiting-time statistic built in, and the initial view, are:
* The time for the picture (switch 1 on): 0x01D8 = 472, i.e. 472\*2^11 clock
  cycles, which was 5.5 ms at 174.55 MHz, and is 5.4 ms (about 184 pictures
  per second) at the current 177.78 MHz. This value is steady. The same
  number of clock cycles was measured with the main clock at
  140.625 MHz (6.9 ms), before the clock was raised (see
  [Resources and timing closure](#resources-and-timing-closure)).
* The waiting time of all the column modules (switch 1 off): 0x720C = 29196,
  i.e. 29196\*2^11 clock cycles in total, which is about a quarter of the
  time of each column module. Before the value was averaged over 64 pictures,
  the lowest bits changed from picture to picture (about 0x721F = 29215 was
  measured), because of the truncation of the wait counters (see
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
0.73 million clock cycles (4.1 ms), so these picture columns decide the total
time. The model gives 472\*2^11 clock cycles for the picture, the same as
measured.

The model gives a total waiting time of 28896\*2^11 clock cycles, i.e. 192
clock cycles per pixel on average. The wait counter of a column module counts
2 clock cycles more for each pixel. With these 2 clock cycles for each of the
307200 pixels, the expected value on the LEDs is 29196 (0x720C), exactly the
measured value.

The wait counter counts from 3 clock cycles after the result is ready until
the clock cycle before the acknowledge reaches the column module. When the
acknowledge was delayed by one more clock cycle (by the registers in the
groups, see [Dispatcher](#dispatcher)), the value on the LEDs did not change:
the column module then starts the next row one clock cycle later, so its next
result is ready one clock cycle later, and waits one clock cycle less for the
scheduler. The waiting time counted for a pixel is the time from one accepted
result of the column module to the next, minus the time the iterator needs
for the pixel, minus a fixed number of clock cycles, and this does not depend
on the delay of the acknowledge. Neither does the time for the picture, because the time from
one result of a column module to the next is still rounded up to the same
multiple of 240 clock cycles.

Without the waiting, the picture would take about 3.3 ms (if the work was
spread evenly over the column modules).

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
the next row while it waits. At this speed (about 184 pictures per second) it
does not matter much, though.

## Resources and timing closure
The numbers below come from a successful run of `make vivado` (Vivado 2025.1,
part xc7a100tcsg324-1, i.e. speed grade -1) with the default settings, i.e.
without the waiting-time statistic (C\_WAIT\_STAT false, see
[The top level](#the-top-level)), which meets timing with a 177.78 MHz main
clock.

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 240      | 240       | 100
| Block RAM        | 128 RAMB36 + 1 RAMB18 | 135 RAMB36 | about 95
| Slices           | 12,602   | 15,850    | 80
| LUTs             | 36,261   | 63,400    | 57
| Registers        | 34,937   | 126,800   | 28
| Clock buffers    | 3 BUFG, 1 MMCM | |

The resource numbers are from `report_utilization` on the routed design
(`mandelbrot.dcp`), and the available numbers are the totals for the XC7A100T.
Most of the slices are used, even though only 57% of the LUTs are used.

The "Report Cell Usage" table in `vivado.log` gives the cell counts after
synthesis instead: 49,160 LUT cells (LUT1 to LUT6) and 34,293 registers (FDRE
and FDSE cells). The number of LUT cells is larger than the number of LUTs
used, because two small LUT cells can share one LUT (the placer does this, e.g.
"LUT Combining" in `phys_opt_design`). There are more registers after
routing than after synthesis, because the physical optimization replicates
registers with a high fanout, and moves some of them (retiming).

With the waiting-time statistic (C\_WAIT\_STAT true), and with only the lower
8 bits of the count in the display memory, the design used 53,386 LUT cells and
44,493 registers after synthesis, and 40,542 LUTs, 46,345 registers, and 14,789
slices (93%) after routing, and the setup slack at 174.55 MHz was +0.094 ns. So
the statistic costs about 4,200 LUT cells and 10,200 registers, mostly for the
27-bit wait counter in each column module and the chain of adders in the
dispatcher.

Before the post-adder of the DSP was used (see [Multiplier](#multiplier)), the
design used 61,895 LUT cells and 53,885 registers after synthesis, and 49,087
LUTs, 53,960 registers, and 15,402 slices (97%) after routing. The timing
slack was about the same (+0.116 ns), because the critical paths were not in
the iterators.

The registers that shorten the routes to the column modules and to the BRAMs
(see [Dispatcher](#dispatcher) and [The top level](#the-top-level)) use about
4,600 registers and 500 LUT cells. Before they were added, the setup slack was
+0.104 ns.

The display memory has 2^19 entries of 9 bits (the count), i.e. 128 blocks of
36 kbit BRAM, each used as 4096 entries of 9 bits (with the parity bits), as
expected. The single RAMB18 is used by the dispatcher, for the table
`job_addr_r` that holds the picture column of each column module (240 entries
of 10 bits).

The timing after routing is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.081 ns (TNS 0)
| Hold (WHS)  | +0.012 ns (THS 0)

These are the values from `report_timing_summary` on the routed design
(`mandelbrot.dcp`), after the post-route `phys_opt_design`.

The timing is met for all clocks. The 177.78 MHz main clock (period 5.63 ns)
is generated from the 100 MHz input clock by the MMCM: it is multiplied by 12,
which gives 1200 MHz (the maximum for speed grade -1), and divided by 6.75.
The main clock uses the output CLKOUT0 of the MMCM, because it is the only
output with a fractional divider. The only constraint in `mandelbrot.xdc` is
the 100 MHz input clock. The MMCM also generates the 25 MHz VGA clock (divided
by 48). The two clocks only meet in the display memory, so there are no timing
paths between them.

At this frequency, the critical paths are mostly logic, not only routing:
* The done flag of the dispatcher (from the busy flags of all the 240 column
  modules to `done_r`), with 22 levels of logic and +0.081 ns of slack.
* The next row in the column modules (from `res_addr_r` through the check for
  the last row to `res_cy_r`), with 8 levels of logic.
* The selection of the column module in the schedulers (from the counter
  `cnt_r` through the 240-to-1 multiplexer of the busy flags to
  `job_idx_start_r`), with 5 or 6 levels of logic.
* The reset from the top level to the view control and the schedulers, and the
  routes from the registers in the groups to the column modules.
All of these have less than 0.26 ns of slack. To go faster, the first three
would have to be pipelined (at 192 MHz, the next row and the schedulers fail
timing).

At 140.625 MHz, the critical paths were first the routes from single registers
to all 240 column modules (the job, the reset, and the index of the column
module whose result is accepted) or to all 128 BRAMs (the write address),
before the registers in the groups and the blocks were added, and before that
the selection of the column module in the schedulers, and the iterators (from
the multiplier through the addition of cx to x\_r, before the post-adder of
the DSP was used). The directives used in
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
and the main clock was lowered to 140.625 MHz. After the post-adder of the DSP
was used and the registers in the groups and the blocks were added, the design
met timing at 140.625 MHz with +0.342 ns of slack. The same design was then
built for higher frequencies, by changing only the MMCM:

| Main clock | Setup slack | Main clock | Setup slack
| ---------- | ----------- | ---------- | -----------
| 143.75 MHz | +0.274 ns   | 162.71 MHz | +0.129 ns
| 146.88 MHz | +0.131 ns   | 165.52 MHz | +0.125 ns
| 150.00 MHz | +0.187 ns   | 168.42 MHz | +0.046 ns
| 152.38 MHz | +0.237 ns   | 171.43 MHz | +0.018 ns
| 154.84 MHz | +0.160 ns   | 174.55 MHz | +0.094 ns
| 157.38 MHz | +0.058 ns   | 177.78 MHz | +0.004 ns
| 160.00 MHz | +0.093 ns   | 181.13 MHz | -0.099 ns

The slack does not decrease steadily with the frequency, because the tools
work harder when the timing is tighter, and the result of each run varies by
about 0.1 ns. Above 174.55 MHz the result depends on luck: 177.78 MHz (and
184.62 MHz) met timing by a few picoseconds, after the post-route physical
optimization, but 181.13 MHz did not. So the main clock was raised to
174.55 MHz, which is 24% faster than 140.625 MHz.

These builds had the waiting-time statistic. Without it (the default), the
slack at 174.55 MHz was +0.229 ns instead of +0.094 ns, so the frequency was
tried again:

| Main clock | Setup slack | Hold slack
| ---------- | ----------- | ----------
| 177.78 MHz | +0.081 ns   | +0.012 ns
| 181.13 MHz | +0.040 ns   | +0.014 ns
| 184.62 MHz | +0.020 ns   | +0.021 ns
| 188.24 MHz | +0.003 ns   | +0.000 ns
| 192.00 MHz | -0.061 ns   | +0.007 ns

The main clock was raised to 177.78 MHz, which has about the same slack as
174.55 MHz had with the waiting-time statistic. It is 26% faster than
140.625 MHz.

The complete run of `make vivado` takes about 6.5 minutes (synthesis about 2.5
minutes, placement about 1.5 minutes, routing about 1 minute), on a machine
with 8 threads.

All 240 DSPs running at 177.78 MHz gives a peak of 43 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 28 billion multiplications per second.
