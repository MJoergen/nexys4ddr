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
 +- clk_rst                     src/clk_rst.vhd (MMCM, clock buffers and resets)
 +- main                        src/main/main.vhd (everything in the MAIN clock domain)
 |   +- view                    src/main/view.vhd (view control from the buttons)
 |   +- dispatcher              src/main/dispatcher.vhd
 |   |   +- scheduler           (i_scheduler, selects the column module to receive a job)
 |   |   +- column  (x 240)     src/main/column.vhd (the column modules)
 |   |   |   +- iterator        src/main/iterator.vhd
 |   |   |       +- (DSP48E1)   (inferred in p_dsp, multiplier and adder)
 |   |   +- scheduler           (i_scheduler_res, selects the column module whose result is accepted)
 |   +- fps                     src/main/fps.vhd (frame rate, calculated from the time for a picture)
 |   +- seg                     src/main/seg.vhd (7-segment display)
 +- disp_mem                    src/disp_mem.vhd (display memory, between the two clock domains)
 +- vga                         src/vga/vga.vhd (everything in the VGA clock domain)
     +- pix                     src/vga/pix.vhd (pixel counters)
     +- disp                    src/vga/disp.vhd (VGA output, uses the palettes in src/vga/palette_pkg.vhd)
```
The number of column modules (and therefore iterators and DSPs) is set by the
generic `G_NUM_ITERATORS`, which `main` sets to 240.

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
`p_dsp` and the addition after it in [`src/main/iterator.vhd`](src/main/iterator.vhd), so
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
This component ([`src/main/iterator.vhd`](src/main/iterator.vhd)) performs the main
calculation. It takes as input the complex number c (or rather the real and
imaginary values cx and cy). It then iterates the Mandelbrot function a number
of times and stops when either the maximum iteration count is reached, or an
overflow occurs.

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

The testbench for the iterator ([`sim/iterator_tb.vhd`](sim/iterator_tb.vhd))
is self-checking. It runs a few starting values (in the set, escaping
immediately, escaping quickly, and escaping slowly), and compares the count
with one calculated using real (floating point) numbers. The counts must be
equal, within a small tolerance. For the points in the set it also checks that
the periodicity detection stops the iteration long before the maximum count.
Then it compares the count exactly with the bit-accurate model (see below) for
a grid of 40 x 30 points over the initial view, and for six points that were
found by a search with the model, where x or y alone repeats a saved value
before the point escapes. These fail if the detection compares only x or only
y. The script
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

### Periodicity detection
Points in the Mandelbrot set never overflow, so they would take the maximum
number of iterations (511). For the initial view, 28% of the pixels are in the
set, and they need 95% of all the iterations. But for most of them the values
of x and y start to repeat exactly after a while: x and y have only 18 bits
each, so an orbit that converges to a fixed point or a cycle ends up in an
exact cycle of values. Once the values after iteration n are equal to the
values after an earlier iteration m, the iteration repeats the same values for
ever, without an overflow, so the count is the maximum count. So the iterator
can stop as soon as it sees a repeated value, and the count is exactly the
same as without stopping early.

This is detected in the same way as in Brent's cycle detection algorithm. The
values of x and y are saved (sx\_r and sy\_r) after the iterations 1, 2, 4,
8, 16, and so on, i.e. after each power of two. In each iteration from
iteration 2 (in ADD\_ST) the current values are compared with the saved
values. The saved registers are not cleared at the start of a point, because
the clear would need an extra LUT for each bit; they are only loaded, using
the clock enable. The saved values are from an earlier iteration, and the gap between the saved
iteration and the current one keeps growing, so a cycle is found once the
saved values are in the cycle and the gap is at least the length of the
cycle. Both x and y must be equal: in rare cases only one of them repeats,
for points that escape later.

The result of the comparison is registered (match\_r), and used in the next
ADD\_ST, so the comparison is not in the paths of the iteration itself. The
iterator then stops with the count G\_MAX\_COUNT, one iteration after the
match. The detection uses two 18-bit registers and a 36-bit comparison in
each iterator.

For the initial view, the detection stops 78161 of the 87175 pixels in the set
early, and the iterator needs 132 clock cycles per pixel on average, instead
of 460. The rest of the pixels in the set (near the edge of the set) do not
reach a cycle within 511 iterations.

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
* A *picture column* is a vertical slice of the picture.
* A *job* is 120 rows of a picture column, i.e. a quarter of it. The picture is
  divided into four *blocks* of 120 rows, so there are 2560 jobs.
* A *column module* is an instance of [`src/main/column.vhd`](src/main/column.vhd). It
  calculates one job at a time, row by row, using one iterator.
* An *iterator* is the block in [`src/main/iterator.vhd`](src/main/iterator.vhd). It
  calculates the count for a single point.

There is one iterator, and therefore one DSP, in each column module, and there
are `G_NUM_ITERATORS` column modules (240 in the design). The generics keep
their names: `G_NUM_COLS` is the number of picture columns, and
`G_NUM_ITERATORS` is the number of column modules. The number of rows in a job
is the generic `G_JOB_ROWS` of the dispatcher (`C_JOB_ROWS` in `main.vhd`),
which is the generic `G_NUM_ROWS` of the column module.

Each job is calculated in its entirety by one column module.

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
calculation of a job, and the output job\_busy\_o remains high until the entire
calculation is finished. The value job\_starty\_i is cy of the first row of
the job.

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
The res\_addr\_o is the current row number, counted from the first row of the
job, and res\_data\_o is the calculated count value for this pixel. The res\_ack\_i is needed, because there may be an
arbitrarily long delay before the job dispatcher has time to acknowledge the
result.

The testbench for the column module ([`sim/column_tb.vhd`](sim/column_tb.vhd))
is self-checking. It runs three jobs of ten rows each, and checks that the
column module is busy only during a job, that the results come in order, that a
result stays unchanged until it is acknowledged (the acknowledge is delayed by a
varying number of clock cycles), and that the count for each row is exactly the
count calculated by the bit-accurate model (see [Iterator](#iterator)). The
third job is near the top of the set, where x+y or x-y is often out of range.

## Dispatcher
This ([`src/main/dispatcher.vhd`](src/main/dispatcher.vhd)) is essentially the top level
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
[The top level](#the-top-level).

This module instantiates a configurable number of column modules (ideally 240
instances, one for each DSP). It keeps track of which column modules are
currently calculating, and whenever a column module is idle, the next job is
sent to it.

The jobs are given out one block at a time: first all 640 picture columns of
the top 120 rows, then all the picture columns of the next 120 rows, and so
on. After the last picture column of a block, cx starts again from the left
edge, and starty moves to the next block, by adding 120 times stepy (in 18
bits, like the column modules add stepy, so cy of each row is the same as if
the picture column was calculated in one job). The multiplication by the
constant 120 is done once for each picture, in LUTs, because all the DSPs are
used by the iterators. The dispatcher keeps the picture column and the block
of the job of each column module, and when a result is accepted it adds the
first row of the block to the row from the column module, to get the address
in the display memory.

Smaller jobs make the work more evenly shared between the column modules at
the end of the picture, see [Timing](#timing). The order of the jobs matters
less: other orders were tried in the model (e.g. column by column, or starting
from the middle of the picture), and the best order depends on the view.

A separate scheduler module is used to send jobs to the different column
modules. Currently, the scheduler operates in a round-robin fashion. This
potentially may give a delay up to 240 clock cycles before an idle column module
is given a job, i.e. 1.3 us at 188.24 MHz. The column modules wait in
parallel, and with 2560 jobs and 240 column modules, each column module gets
about 11 jobs on average. So the delay adds at most about 15 microseconds (and
half of that on average) to the time for a picture, which is about 2.2 ms. This
delay is small.

The scheduler ([`src/main/scheduler.vhd`](src/main/scheduler.vhd)) has a counter that
goes round all the column modules, one per clock cycle, and selects a column
module when the counter reaches it and it is idle. Selecting the busy flag of
one of the 240 column modules in a single clock cycle is too slow, so it is
done in two steps: first, in each group of 16 column modules, the busy flag at
the position of the counter in the group is registered, and in the next clock
cycle the flag of the group of the counter is used.

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
five clock cycles after it has sampled its busy flag and selected it, so the
dispatcher needs at least five column modules.

The done flag (done\_o) needs to know that all 240 column modules are idle. The
busy flags are first combined in each group of 16 column modules, in a
register, and then the 15 groups are combined. The done flag is not set while
a job has just been started, until the busy flag of the column module has
reached the register of its group.

The dispatcher has a self-checking testbench
([`sim/dispatcher_tb.vhd`](sim/dispatcher_tb.vhd)). It calculates two small
pictures (64 by 16 pixels, with 16 column modules in groups of 5, so the last
group is smaller, and four jobs of 4 rows in each picture column), one right
after the other,
and checks that each pixel is written exactly once, that everything has been
written when done\_o goes high, that done\_o goes low when a new picture is
started, and that the value of each pixel is exactly the count calculated by
the bit-accurate model (see [Iterator](#iterator)) for the value of c of that
pixel. This also checks that each result is written to the right address. It
then repeats this for two pictures with a single picture
column, i.e. with fewer picture columns than column modules, which is a special
case for done\_o, and with jobs of a single row, so every job is the last
picture column of its block. The simulation takes about 10 seconds.

The scheduler has a small self-checking testbench
([`sim/scheduler_tb.vhd`](sim/scheduler_tb.vhd)), with 21 processes, i.e. two
groups, where the second one is smaller. It checks that nothing is started
when the scheduler is not active or when everything is busy, that each idle
process is started once per round and busy processes never, that the
processes are started in round-robin order, and that reset restarts the
scheduler from the first process.

## The top level
The top level ([`src/mandelbrot.vhd`](src/mandelbrot.vhd)) instantiates the
clock and reset generation ([`src/clk_rst.vhd`](src/clk_rst.vhd)) and the
display memory, and splits the rest of the design into one module for each
clock domain:
* [`src/main/main.vhd`](src/main/main.vhd) runs in the MAIN clock domain (188.24 MHz).
  It handles the buttons and switches, controls the dispatcher, writes the
  results to the display memory, and shows the frame rate on the 7-segment
  display.
* [`src/vga/vga.vhd`](src/vga/vga.vhd) runs in the VGA clock domain (25 MHz). It
  generates the pixel counters, reads the display memory, and generates the VGA
  output.

The two clock domains communicate only through the display memory, which has
a write port in the MAIN clock domain and a read port in the VGA clock domain.
The files used only in the MAIN clock domain are in [`src/main/`](src/main),
and the files used only in the VGA clock domain are in [`src/vga/`](src/vga).
The top level, the clock and reset generation, and the display memory, which
are in both clock domains, are in [`src/`](src).

**Reset.** The resets are generated in `clk_rst`, together with the clocks.
The design is held in reset while the reset button is pressed, and while the
MMCM is not locked. This signal is synchronized to each clock domain (the main
clock and the VGA clock), and the reset is then stretched to eight clock cycles
after it is released. The VGA reset is connected to the `vga`
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

The view is controlled by the module [`src/main/view.vhd`](src/main/view.vhd). It is
updated at a fixed rate, which is given by a counter of 23 bits in `main.vhd`.
At 188.24 MHz this is once every 45 ms, i.e. about 22 times per second. At
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

**The frame rate.** The 7-segment display shows the frame rate, i.e. the
number of pictures per second, rounded down to an integer, with the leading
zeros blanked. A counter counts clock cycles while a picture is being
calculated, and it is cleared when the next picture is started. At the end of
a picture, the module [`src/main/fps.vhd`](src/main/fps.vhd) divides the clock frequency
(188,235,294 Hz) by the value of the counter, and converts the result to
decimal. The picture is recalculated continuously, so the frame rate is
updated after every picture (about 340 times per second for the initial view).
A single-cycle division would be far too slow for the MAIN clock, so both
steps are done one bit per clock cycle: a restoring division, with one
subtraction for each of the 28 bits of the quotient, and then the double
dabble algorithm to convert the quotient to 8 decimal digits (for each bit, 3
is added to each digit which is 5 or more, and then everything is shifted left
by one bit). This takes 58 clock cycles, much less than a picture, and the
widest addition is 29 bits. A frame rate above 99999999 would show as
99999999, but that would need a picture of fewer than 2 clock cycles. The
counter is 27 bits wide, so it wraps around after 2^27 clock cycles (0.71 s),
but a picture takes far less than that: even if every pixel took the maximum
of 1680 clock cycles (see [Timing](#timing)), a picture would take about 3
million clock cycles (16 ms).

The digits of the display share the segment signals, so
[`src/main/seg.vhd`](src/main/seg.vhd) shows them one at a time, each for 2^14 clock
cycles, i.e. all 8 digits are refreshed every 0.67 ms (1.5 kHz). The
segments and the digit enables (anodes) are active low. The decimal point is
not used.

The testbench [`sim/fps_tb.vhd`](sim/fps_tb.vhd) is self-checking. It gives
the frame rate module a number of picture times (the extremes, the values
around a change of the frame rate, e.g. 199 and 200, and random values), and
checks the digits and the blanking against the integer division, and that the
display shows the same number: every digit that is not blanked is switched on
with the right segments during a refresh cycle, the blanked digits are never
switched on, and at most one digit is on at a time. It also checks that a new
picture time during a calculation is ignored.

**Other inputs.** The switches 3 and 4 select the colour palette, see
[Colours](#colours). They are used in the VGA clock domain (in `vga`), not in
`main`. The switches 0, 1 and 5 to 7 are not used.

## Colours
The display memory holds the count of each pixel (9 bits). The VGA output has
8 bits of colour, in the format RRRGGGBB (3 bits red, 3 bits green, and 2 bits
blue). The points in the set (count 511) get the colour of the set. For the
other counts, the lower 8 bits of the count (the value) are converted to the
colour by one of four palettes in [`src/vga/palette_pkg.vhd`](src/vga/palette_pkg.vhd),
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
A counter measures the time it takes to generate the picture, which is shown
as a frame rate on the 7-segment display, see [The top level](#the-top-level).
Earlier versions showed this time on the LEDs instead, in units of 2^11 clock
cycles, and also (with switch 1) the total amount of time the column modules
were waiting to write to the display memory, when the waiting-time statistic
was enabled. The LEDs are no longer used, and the counters for the waiting
time have been removed.

The numbers measured on the board, with the main clock at 174.55 MHz, the
waiting-time statistic built in, and the initial view, were:
* The time for the picture (switch 1 on): 0x01D8 = 472, i.e. 472\*2^11 clock
  cycles, which was 5.5 ms at 174.55 MHz. This value is steady. The same
  number of clock cycles was measured with the main clock at 140.625 MHz
  (6.9 ms), before the clock was raised (see
  [Resources and timing closure](#resources-and-timing-closure)). This was
  before the periodicity detection (see [Iterator](#iterator)), and before
  the schedulers and the done flag were pipelined (see
  [Dispatcher](#dispatcher)).
* The waiting time of all the column modules (switch 1 off): 0x720C = 29196,
  i.e. 29196\*2^11 clock cycles in total, which is about a quarter of the
  time of each column module. Before the value was averaged over 64 pictures,
  the lowest bits changed from picture to picture (about 0x721F = 29215 was
  measured), because each wait counter was truncated to units of 2^11 clock
  cycles before the sum.

Both values agree with the model [`sim/model.py`](sim/model.py), which
estimates the time for the picture from the number of iterations of each pixel,
as follows. A column module uses 3 clock cycles per iteration, plus 7 clock
cycles to start the iterator and to deliver the result, i.e. 3n+7 clock
cycles, where n is the number of iterations done when the iterator stops: the
count for a pixel that escapes, 510 for a pixel that reaches the maximum
count, and the iteration after the match for a pixel where a cycle is found.
Then the result must be accepted by the dispatcher. The round-robin scheduler for the results (i\_scheduler\_res)
checks each column module once every 240 clock cycles, so the time from one
result of a column module to the next is always a multiple of 240 clock
cycles. This has been checked in simulation. So:
* A pixel with a count up to 77 takes 240 clock cycles, i.e. the iterator is
  idle for most of the time, waiting for the result to be accepted.
* A pixel in the set that does not reach a cycle takes 3\*510+7 = 1537 clock
  cycles, which is rounded up to 1680 clock cycles. Before the periodicity
  detection, this was the case for all the pixels in the set.

Without the periodicity detection, the iterator needed 460 clock cycles per
pixel on average for the initial view (the average count is 151), but each
pixel took 652 clock cycles on average, including the waiting. A single
picture column through the middle of the set took up to 0.73 million clock
cycles, so these picture columns decided the total time. The model gave
472\*2^11 clock cycles for the picture, the same as measured.

With the periodicity detection, the iterator needs 132 clock cycles per pixel
on average, and each pixel takes 316 clock cycles on average, including the
waiting. Most of the pixels now take the minimum of 240 clock cycles, and the
longest picture column takes 0.27 million clock cycles. When each job was a
whole picture column, the model gave 551040 clock cycles (269\*2^11) for the
picture, i.e. 2.9 ms at 188.24 MHz, 1.75 times faster than without the
detection (about 341 pictures per second).

With 640 jobs and 240 column modules, each column module got fewer than three
jobs, so the work was not shared evenly at the end of the picture: if the
work was spread evenly over the column modules, each of them would need
404875 clock cycles. With jobs of 120 rows (2560 jobs), the longest job takes
0.11 million clock cycles, and the model gives 418560 clock cycles
(204\*2^11) for the picture, i.e. 2.22 ms at 188.24 MHz, 1.32 times faster.
So the 7-segment display should show about 450 pictures per second. The
model gives 465840 clock cycles for jobs of 240 rows, and 413040 clock cycles
for jobs of 60 rows. Eight other views (zoomed in at different places) were
1.07 to 1.31 times faster in the model with jobs of 120 rows than with whole
picture columns. None of this
has been measured on the board yet.

Without the periodicity detection, the model gave a total waiting time of
59,179,719 clock cycles, i.e. 28896\*2^11 clock cycles, or about 193 clock
cycles per pixel on average. The wait counter of a column module counted 2
clock cycles more for each pixel. With these 2 clock cycles for each of the
307200 pixels, the expected value on the LEDs was 29196 (0x720C), exactly the
measured value. The wait counters have been removed from the design, so the
model is now the way to get this value: `sim/model.py` prints both numbers
(the total waiting time, and the value the wait counters would have shown).
With the periodicity detection, the wait counters would show about 27981.

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

Without the waiting, the picture would take about 0.9 ms (if the work was
spread evenly over the column modules). So the time for the picture is now
mostly decided by the round-robin scheduler for the results, which accepts a
result from each column module only once every 240 clock cycles.

Similar values (472\*2^11 clock cycles for the picture, and 28642\*2^11 clock
cycles of waiting) were measured earlier, with an iterator which did not detect
all overflows and which calculated x+y and x-y in 18 bits (see
[Overflow](#overflow)), and with a main clock of 150 MHz. The time for the
picture did not change, because it is decided by the picture columns through
the middle of the set, where most of the pixels reach the maximum count.

This could be improved by accepting a result as soon as it is ready, e.g.
with a priority encoder instead of the round-robin scheduler, or by
storing a few results in each column module, so the iterator can continue with
the next row while it waits.

## Resources and timing closure
The numbers below come from a successful run of `make vivado` (Vivado 2025.1,
part xc7a100tcsg324-1, i.e. speed grade -1), which meets timing with a
188.24 MHz main clock.

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 240      | 240       | 100
| Block RAM        | 128 RAMB36 + 2 RAMB18 | 135 RAMB36 | about 96
| Slices           | 14,641   | 15,850    | 92
| LUTs             | 41,284   | 63,400    | 65
| Registers        | 44,562   | 126,800   | 35
| Clock buffers    | 3 BUFG, 1 MMCM | |

The resource numbers are from `report_utilization` on the routed design
(`mandelbrot.dcp`), and the available numbers are the totals for the XC7A100T.
Most of the slices are used, even though only 65% of the LUTs are used.

The "Report Cell Usage" table in `vivado.log` gives the cell counts after
synthesis instead: 54,492 LUT cells (LUT1 to LUT6) and 42,708 registers (FDRE
and FDSE cells). The number of LUT cells is larger than the number of LUTs
used, because two small LUT cells can share one LUT (the placer does this, e.g.
"LUT Combining" in `phys_opt_design`). There are more registers after
routing than after synthesis, because the physical optimization replicates
registers with a high fanout, and moves some of them (retiming).

The periodicity detection (see [Iterator](#iterator)) uses about 5,500 LUT cells
and 8,900 registers (36 registers for the saved values in each iterator), and
increased the slices used from 81% to 93%. A first version, which cleared the
saved values at the start of each point, used about 4,100 LUT cells more.

With the waiting-time statistic built in, and with only the lower
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
expected. The two RAMB18s are used by the dispatcher, for the tables
`job_addr_r` and `job_blk_r` that hold the picture column and the block of the
job of each column module (240 entries of 10 bits, and of 2 bits).

The jobs of 120 rows (see [Dispatcher](#dispatcher)) did not use more
resources: before them, the design used 55,536 LUT cells and 43,656 registers
after synthesis, and 42,158 LUTs, 46,314 registers, and 14,764 slices (93%)
after routing, with a setup slack of +0.045 ns. The column modules need fewer
bits for the row (7 instead of 9), which saves more than the dispatcher
needs for the blocks.

The timing after routing is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.103 ns (TNS 0)
| Hold (WHS)  | +0.014 ns (THS 0)

These are the values from `report_timing_summary` on the routed design
(`mandelbrot.dcp`), after the post-route `phys_opt_design`.

The timing is met for all clocks. The 188.24 MHz main clock (period 5.31 ns)
is generated from the 100 MHz input clock by the MMCM: it is multiplied by 12,
which gives 1200 MHz (the maximum for speed grade -1), and divided by 6.375.
The main clock uses the output CLKOUT0 of the MMCM, because it is the only
output with a fractional divider. The only constraint in `mandelbrot.xdc` is
the 100 MHz input clock. The MMCM also generates the 25 MHz VGA clock (divided
by 48). The two clocks only meet in the display memory, so there are no timing
paths between them.

At this frequency, the critical paths are in the iterators, and in the column
modules around them:
* From the output of the DSP (which is not registered, see
  [Multiplier](#multiplier)) to the overflow flags.
* From x\_r and y\_r through the additions x+y and x-y and the selection of
  the inputs of the multiplier to the input registers of the DSP, with 6 or 7
  levels of logic.
* The acknowledge of the results (`res_ack_r`) to the row in the column
  modules, and the routes from the registers in the groups to the column
  modules.
* The state machine of the iterator (from cnt\_r and state\_r), and the
  periodicity detection (to match\_r and the saved values). In the latest
  build, the worst path (+0.103 ns) is from state\_r to the clock enable of
  the saved values.
* The next row in the column modules (to `res_cy_r`, whose clock enable
  depends on the result of the iterator).
To go faster, the iterator would have to be changed, e.g. by registering the
output of the DSP, which would change the three clock cycles of an iteration.

At 177.78 MHz, before the next row in the column modules, the schedulers and
the done flag were pipelined (see [Dispatcher](#dispatcher)), these were the
critical paths, with up to 22 levels of logic (the done flag).

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

These builds had the waiting-time statistic. Without it, the
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
174.55 MHz had with the waiting-time statistic.

Then the next row in the column modules, the schedulers and the done flag were
pipelined, and the frequency was tried again:

| Main clock | Setup slack | Hold slack
| ---------- | ----------- | ----------
| 188.24 MHz | +0.027 ns   | +0.016 ns
| 192.00 MHz | +0.064 ns   | +0.014 ns
| 195.92 MHz | +0.132 ns   | +0.014 ns
| 200.00 MHz | +0.003 ns   | +0.021 ns
| 204.26 MHz | +0.001 ns   | +0.051 ns
| 208.70 MHz | -0.075 ns   | +0.014 ns

The main clock was raised to 195.92 MHz, which has more slack than the
frequencies just below and above it. The pipelining costs about 700 LUT cells
and 300 registers.

The periodicity detection (see [Iterator](#iterator)) increased the slices
used from 81% to 93%, and the slack at 195.92 MHz dropped to +0.004 ns. With
the detection:

| Main clock | Setup slack | Hold slack
| ---------- | ----------- | ----------
| 188.24 MHz | +0.088 ns   | +0.017 ns
| 192.00 MHz | +0.029 ns   | +0.016 ns
| 195.92 MHz | +0.004 ns   | +0.014 ns

So the main clock was lowered to 188.24 MHz, which has about the same slack as
the earlier choices. This is 4% slower than 195.92 MHz, but the detection
makes the picture 1.75 times faster. The main clock is 34% faster than
140.625 MHz. The frame rate on the 7-segment display (see
[The top level](#the-top-level)), which replaced the LEDs and the waiting-time
statistic, uses about 170 LUT cells and 180 registers, and the build with it
has +0.045 ns of setup slack at 188.24 MHz. The difference from +0.088 ns is
the normal variation from one run to the next; the critical paths are the
same.
The build with the jobs of 120 rows (see [Dispatcher](#dispatcher)), at the
same frequency, has +0.103 ns of setup slack.

The complete run of `make vivado` takes about 6.5 minutes (synthesis about 2.5
minutes, placement about 1.5 minutes, routing about 1 minute), on a machine
with 8 threads.

All 240 DSPs running at 188.24 MHz gives a peak of 45 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 30 billion multiplications per second.
