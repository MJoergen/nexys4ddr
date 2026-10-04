# The algorithm and its implementation
This describes in some detail how the Mandelbrot design works, and the main
parts it is built from. See [README.md](README.md) for an overview, a list of
files, and how to build and run the design.

The design is implemented on the Nexys 4 DDR board, which uses a Xilinx FPGA
XC7A100T. This FPGA has a total of 240 DSPs, which are all used for the actual
calculations. Additionally, the FPGA contains 135 BRAMs (of 36 kbit each),
which are used for storing the results of the calculation, i.e. the actual
picture to be displayed. The same design also runs on the MEGA65 R6, with a
larger FPGA (XC7A200T) and a resolution of 1280x1024 instead of 640x480, see
[MEGA65 R6](#mega65-r6). The numbers in this document are for the Nexys 4 DDR,
unless stated otherwise.

## Terms
The following terms are used in this document:
* A *picture column* is a vertical slice of the picture.
* A *job* is 120 rows of a picture column, i.e. a quarter of it. The picture is
  divided into four *blocks* of 120 rows, so there are 2560 jobs.
* A *job module* is an instance of [`src/main/job.vhd`](src/main/job.vhd). It
  calculates one job at a time, row by row, using one iterator.
* An *iterator* is the block in [`src/main/iterator.vhd`](src/main/iterator.vhd). It
  calculates the count for a single point.

## Instantiation hierarchy
The modules are instantiated as follows:
```
nexys4ddr                       src/nexys4ddr.vhd (top level)
 +- clk_rst                     src/clk_rst.vhd (MMCM, clock buffers and resets)
 +- main                        src/main/main.vhd (everything in the MAIN clock domain)
 |   +- view                    src/main/view.vhd (view control from the buttons)
 |   +- dispatcher              src/main/dispatcher.vhd
 |   |   +- job_scheduler       src/main/job_scheduler.vhd (selects the job module to receive a job)
 |   |   +- job     (x 240)     src/main/job.vhd (the job modules)
 |   |   |   +- iterator        src/main/iterator.vhd
 |   |   |       +- (DSP48E1)   (inferred in p_dsp, multiplier and adder)
 |   |   +- res_scheduler       src/main/res_scheduler.vhd (selects the job module whose result is accepted)
 |   +- fps                     src/main/fps.vhd (frame rate, calculated from the time for a picture)
 |   +- (p_fps_toggle)          (tells the VGA clock domain that the frame rate has changed)
 |   +- seg                     src/main/seg.vhd (7-segment display)
 +- disp_mem                    src/disp_mem.vhd (display memory, between the two clock domains)
 +- (p_fps_cdc)                 (moves the frame rate to the VGA clock domain)
 +- vga                         src/vga/vga.vhd (everything in the VGA clock domain)
     +- pix                     src/vga/pix.vhd (pixel counters, for the video mode in src/vga/video_pkg.vhd)
     +- disp                    src/vga/disp.vhd (VGA output, uses the palettes in src/vga/palette_pkg.vhd)
     +- overlay                 src/vga/overlay.vhd (frame rate overlay, uses the font in src/vga/font_pkg.vhd)
```
The number of job modules (and therefore iterators and DSPs) is set by the
generic `G_NUM_ITERATORS` of `main`, which the top level module sets to 240
(256 for the MEGA65, see `src/mega65_r6.vhd`).

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
the job module and the dispatcher compare every count with this model, and
require them to be equal. The iterator testbench still compares with real
numbers, so that it also checks that the model (i.e. the design) calculates the
Mandelbrot iteration.

The complete picture can be checked bit-accurately too. The script
[`sim/model.py`](sim/model.py) is a vectorized (numpy) version of the same
model, which calculates the count for every pixel of the initial view, using
the same values of c as the design. Run as a script, it compares the model with
a calculation using real numbers. The testbench
[`sim/main_tb.vhd`](sim/main_tb.vhd) runs `main.vhd` with the initial view, and
writes every pixel written to the display memory to the file
`sim/main_out.txt`. The script [`sim/cmp_rtl.py`](sim/cmp_rtl.py) then compares
these values with the model. The first line of the file is the size of the
picture and the address distance between two picture columns, so the script
knows the view and how to decode the addresses. By default it simulates the
design of the Nexys 4 DDR (240 job modules, one pixel in each write,
640x480); the generics of the testbench select the design of the MEGA65 (256
job modules, four pixels in each write, jobs of 64 rows, 1280x1024 with
21 bits of address) with
`GENERICS="G_NUM_ITERATORS=256 G_PIXELS=4 G_ROWS_IN_JOB=64 G_NUM_COLS=1280 G_NUM_ROWS=1024 G_COL_STRIDE=1024 G_ADDR_BITS=21"`,
see the Makefile. A complete picture takes about 1.5 hours to simulate (with
`STOP_TIME=4ms`, and the waveform file is about 5 GB), but a partial picture
can be compared too:
```
make run TB=main STOP_TIME=700us
sim/cmp_rtl.py
```
The 700 us of simulated time (about 13 minutes) gives more than 50000 pixels,
from all 240 job modules. This testbench is not part of `make sim`.

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
the clock enable. The saved values are from an earlier iteration, and the
gap between the saved iteration and the current one keeps growing, so a cycle
is found once the saved values are in the cycle and the gap is at least the
length of the cycle. Both x and y must be equal: in rare cases only one of
them repeats, for points that escape later.

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

## Jobs
There is one iterator, and therefore one DSP, in each job module, and there
are `G_NUM_ITERATORS` job modules (240 in the design). `G_NUM_COLS` is the
number of picture columns, not of job modules. The number of rows in a job
is the generic `G_ROWS_IN_JOB` of the dispatcher (`C_ROWS_IN_JOB` in the top
level: 120 on the Nexys 4 DDR, and 64 on the MEGA65, because 1024 is not a
multiple of 120), which is the generic `G_NUM_ROWS` of the job module.

Each job is calculated in its entirety by one job module.

The inputs to a job module are:
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
res_data_o   : out std_logic_vector(9*G_PIXELS-1 downto 0);
res_valid_o  : out std_logic
```
with the additional input port
```
res_ack_i    : in  std_logic;
```
Each result is the counts of `G_PIXELS` consecutive rows (1 on the Nexys 4
DDR, and 4 on the MEGA65, see [MEGA65 R6](#mega65-r6)), which the dispatcher
writes to the display memory as one word. The res\_addr\_o is the row number of
the first of these rows, counted from the first row of the job, and
res\_data\_o is the calculated counts, with the count of the first row in the
lowest 9 bits. The res\_ack\_i is needed, because there may be an
arbitrarily long delay before the job dispatcher has time to acknowledge the
result. The number of rows in a job must be a multiple of `G_PIXELS`, which
must be a power of two.

When `G_PIXELS` is more than 1, the job module keeps the counts of the
first `G_PIXELS`-1 rows of a result in a register, and starts the next row at
once, in the clock cycle after the iterator is done. So it only waits for the
acknowledge after the last row of a result. Before the next row, the count of
the row is put at the top of the register, which shifts the earlier counts
down, so the count of the first row ends up at the bottom. The register does
not change from the last row of a result until the next row has been
calculated, i.e. until after the acknowledge, so it is output directly, and
only the count of the last row goes through the output register of the job
module. With an output register for all 36 bits, the MEGA65 build used 12,000
more registers.

The testbench for the job module ([`sim/job_tb.vhd`](sim/job_tb.vhd))
is self-checking. It runs three jobs of 12 rows each, and checks that the
job module is busy only during a job, that the results come in order, with
the right row numbers, that a result stays unchanged until it is acknowledged
(the acknowledge is delayed by a varying number of clock cycles), and that the
count for each row is exactly the count calculated by the bit-accurate model
(see [Iterator](#iterator)). The third job is near the top of the set, where
x+y or x-y is often out of range. It does this for 1, 2 and 4 rows in each
result, with three instances of the job module.

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
wr_data_o : out std_logic_vector(9*G_PIXELS-1 downto 0);
wr_en_o   : out std_logic;
```
The data is the 9-bit counts of `G_PIXELS` consecutive rows of a picture
column (a result of a job module, see [Jobs](#jobs)), and the address
is that of the first of them. The counts are stored in the display memory, see
[The top level](#the-top-level).

This module instantiates a configurable number of job modules (240 on the
Nexys 4 DDR, one for each DSP, and 256 on the MEGA65). It keeps track of
which job modules are currently calculating, and whenever a job module
is idle, the next job is sent to it.

The jobs are given out one block at a time: first all the picture columns
(640 on the Nexys 4 DDR) of the top 120 rows, then all the picture columns of
the next 120 rows, and so on. After the last picture column of a block, cx starts again from the left
edge, and starty moves to the next block, by adding 120 times stepy (in 18
bits, like the job modules add stepy, so cy of each row is the same as if
the picture column was calculated in one job). The multiplication by the
constant 120 is done once for each picture, in LUTs, because all the DSPs are
used by the iterators. The dispatcher keeps the picture column and the block
of the job of each job module, and when a result is accepted it adds the
first row of the block to the row from the job module, to get the row in
the picture.

The address in the display memory is the picture column times the generic
`G_COL_STRIDE`, plus the row. On the Nexys 4 DDR `G_COL_STRIDE` is 512, so the
address is the picture column (10 bits) followed by the row (9 bits), and the
multiplication and the addition are only wires. On the MEGA65 `G_COL_STRIDE`
is 1024, so the address is the picture column (11 bits) followed by the row
(10 bits). The address has `G_ADDR_BITS` bits (19 or 21). For other values of
`G_COL_STRIDE` (e.g. 600, when the MEGA65 showed 800x600 in the 2^19 pixels of
the old display memory) the address is calculated in two pipeline stages: the
multiplication by the constant (in LUTs, like the multiplication by
`G_ROWS_IN_JOB`), and then the addition of the row. The extra stage is there for
a power of two too, as registers, so the write has one more clock cycle of
latency than it would need.

Smaller jobs make the work more evenly shared between the job modules at
the end of the picture, see [Timing](#timing). The order of the jobs matters
less: other orders were tried in the model (e.g. column by column, or starting
from the middle of the picture), and the best order depends on the view.

A separate scheduler module is used to send jobs to the different job
modules. Currently, the scheduler for the jobs operates in a round-robin
fashion over all the job modules, one per clock cycle. This potentially
may give a delay up to 240 clock cycles before an idle job module is
given a job, i.e. 1.6 us at 150 MHz. The job modules wait in
parallel, and with 2560 jobs and 240 job modules, each job module gets
about 11 jobs on average. So the delay adds at most about 18 microseconds (and
half of that on average) to the time for a picture, which is about 2.31 ms.
This delay is small.

The scheduler ([`src/main/job_scheduler.vhd`](src/main/job_scheduler.vhd)) has a counter that
goes round all the job modules, one per clock cycle, and selects a job
module when the counter reaches it and it is idle. Selecting the busy flag of
one of the 240 job modules in a single clock cycle is too slow, so it is
done in two steps: first, in each group of 16 job modules, the busy flag at
the position of the counter in the group is registered, and in the next clock
cycle the flag of the group of the counter is used.

The job modules are spread over the whole FPGA, so the signals that go from
the dispatcher to all of them have long routes. To keep each route shorter,
these signals go through an extra register in each group of 16 job modules
(the generic G\_GROUP\_SIZE, so there are 15 groups, or 29 on the MEGA65): the
job (cx, starty, and stepy), the start of the job, the reset, and the index of
the job module whose result is accepted. The registers of the groups are
identical, so they have the attribute `keep`, which prevents the synthesis
tool from merging them.
Each job module registers the reset once more, so the reset register of a
group drives only 16 registers.

A result is accepted in three steps. First, the index of the job module
selected by i\_res\_scheduler goes to the register in each group. Then each
group acknowledges the selected job module, if it is in the group, and
selects its result. Finally, the result is selected from the group of the
job module and written to the display memory. The job module keeps its
result until it has seen the acknowledge, so the result is still there when
its group selects it. Because of the extra registers, the scheduler for the
jobs sees that a job module is busy five clock cycles after it has sampled
its busy flag and selected it, so the dispatcher needs at least five job
modules.

The display memory can take one result (one word of `G_PIXELS` pixels) in each
clock cycle, and the scheduler
for the results ([`src/main/res_scheduler.vhd`](src/main/res_scheduler.vhd),
i\_res\_scheduler) tries to use as many of these clock cycles as possible.
Each group of 16 job modules (the same groups as above) registers the
ready flags of its job modules, and then, in the next clock cycle, a
candidate: one of its job modules that has a result ready, picked in
round-robin order within the group, i.e. the first one after the job module
that was accepted last time. The ready flags are registered first, so that the
routes from the job modules and the round-robin selection are in separate
clock cycles. A counter goes round the 15
groups, one per clock cycle, and the candidate of the group of the counter is
accepted, if the group has one. So, unlike an idle job module waiting for
a job, a job module with a result waits until
its group is visited, i.e. at most 15 clock cycles, plus 15 clock cycles for
each job module of its group that is before it in the round-robin order.
Earlier, the round-robin scheduler for the jobs was used for the results too,
and a job module waited up to 240 clock cycles for each result, also when
no other job module had a result ready (see [Timing](#timing)).

A job module has a result ready when its result is valid and has not been
acknowledged. The ready flags and the candidate of a group are registered, so
a job module that has just been accepted can still be the candidate of its
group for three more clock cycles, until the acknowledge has reached it and
the ready flags have been registered again. The counter therefore visits each
group at most once every five clock cycles (when there are fewer than five
groups, the counter has empty positions), so a job module can not be
accepted twice for the same result.

The done flag (done\_o) needs to know that all 240 job modules are idle. The
busy flags are first combined in each group of 16 job modules, in a
register, and then the 15 groups are combined. The done flag is not set while
a job has just been started, until the busy flag of the job module has
reached the register of its group.

The dispatcher has a self-checking testbench
([`sim/dispatcher_tb.vhd`](sim/dispatcher_tb.vhd)). It calculates two small
pictures (64 by 16 pixels, with 16 job modules in groups of 5, so the last
group is smaller, and four jobs of 4 rows in each picture column), one right
after the other,
and checks that each pixel is written exactly once, that everything has been
written when done\_o goes high, that done\_o goes low when a new picture is
started, and that the value of each pixel is exactly the count calculated by
the bit-accurate model (see [Iterator](#iterator)) for the value of c of that
pixel. This also checks that each result is written to the right address. It
then repeats this for two pictures with a single picture
column, i.e. with fewer picture columns than job modules, which is a special
case for done\_o, and with jobs of a single row, so every job is the last
picture column of its block. Finally it repeats this for two pictures with
four pixels in each write (and two jobs of 8 rows in each picture column), and
checks that each write starts at a row that is a multiple of 4. The first two
instances have 512 and 16 addresses for each picture column, so the address
is the picture column followed by the row, and the third has 20, which is not
a power of two (like 600 when the MEGA65 showed 800x600). The simulation takes about 10
seconds.

The scheduler has a small self-checking testbench
([`sim/job_scheduler_tb.vhd`](sim/job_scheduler_tb.vhd)), with 21 processes, i.e. two
groups, where the second one is smaller. It checks that nothing is started
when the scheduler is not active or when everything is busy, that each idle
process is started once per round and busy processes never, that the
processes are started in round-robin order, and that reset restarts the
scheduler from the first process.

The scheduler for the results has a self-checking testbench too
([`sim/res_scheduler_tb.vhd`](sim/res_scheduler_tb.vhd)). Each process
behaves like a job module: when it has a result, it is ready until the
result has been accepted, and its ready flag goes low as late as allowed. It
then gets a new result after a random delay. The testbench checks that
nothing is selected when the scheduler is not active or nothing is ready,
that only a process that is ready is selected and each result only once, that
every ready process is selected within the expected time (also when all the
processes are ready all the time), and that all the results are selected. It
does this for 21 processes in groups of 5 (so the last group is smaller), and
for 6 processes in a single group (so the counter has empty positions).

## The top level
The top level ([`src/nexys4ddr.vhd`](src/nexys4ddr.vhd)) instantiates the
clock and reset generation ([`src/clk_rst.vhd`](src/clk_rst.vhd)) and the
display memory, and splits the rest of the design into one module for each
clock domain:
* [`src/main/main.vhd`](src/main/main.vhd) runs in the MAIN clock domain (150 MHz, or 148.97 MHz on the MEGA65).
  It handles the buttons and switches, controls the dispatcher, writes the
  results to the display memory, and shows the frame rate on the 7-segment
  display.
* [`src/vga/vga.vhd`](src/vga/vga.vhd) runs in the VGA clock domain (the pixel
  clock, 25 MHz for 640x480 on the Nexys 4 DDR, and 108 MHz for 1280x1024 on
  the MEGA65). It generates the pixel counters, reads the display memory, and
  generates the VGA output, with the frame rate in the top right corner.

The two clock domains communicate through the display memory, which has a
write port in the MAIN clock domain and a read port in the VGA clock domain.
The only other signals between them are the frame rate and a toggle signal,
which tells the VGA clock domain that the frame rate has changed, see
the paragraph *The frame rate* below.
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
([`src/disp_mem.vhd`](src/disp_mem.vhd)) has `G_NUM_BLOCKS`*4096 pixels of 9
bits: 2^19 on the Nexys 4 DDR, and 1280*1024 (1,310,720) on the MEGA65. The
address of a pixel is the picture column times `G_COL_STRIDE` plus the row
(see [Dispatcher](#dispatcher)), i.e. the picture column (10 bits) followed by
the row (9 bits) on the Nexys 4 DDR, and the picture column (11 bits) followed
by the row (10 bits) on the MEGA65. The 640x480 picture of the Nexys 4 DDR
only uses the first 327,680 pixels (80 of the 128 blocks). The dispatcher delivers a 9-bit count for each pixel, and `main` writes
all 9 bits. The `vga` module converts the count to the colour, in the format
RRRGGGBB, see [Colours](#colours) below.

Each entry of the memory (a word) holds `G_PIXELS` pixels, i.e. consecutive
rows of a picture column, with the first row in the lowest 9 bits. The write
port writes a whole word, at the address of its first pixel (whose lowest bits
must be zero), and the read port reads a single pixel. So the VGA side is the
same for any `G_PIXELS`. The memory is divided into `G_NUM_BLOCKS` blocks of
2^12 pixels (128 on the Nexys 4 DDR, and 320 on the MEGA65), one BRAM each,
selected by the top bits of the address. A 36 kbit BRAM holds 4096
entries of 9 bits, or 1024 entries of 36 bits (the ninth bit of each byte is
the parity bit), so the ninth bit needs no extra BRAMs, and the number of BRAMs
is the same for 1 and 4 pixels in each word. The blocks are in groups of 8
(16 groups on the Nexys 4 DDR, and 40 on the MEGA65). The write address and
data go to the blocks through a tree of registers: first to a register in each
group, and then to a register for each block, which can be placed next to its
BRAM. A single register for the address of all 128 BRAMs, which are spread
over the whole FPGA, made the routing too slow. On the MEGA65 the registers of
the blocks are left out (the generic `G_BLOCK_REGS`), so the register of each
group drives the 8 BRAMs of the group directly. This saves about 15,000
registers, which the job modules need. Writes to addresses beyond the last
block are ignored. The write port has three clock cycles of latency (two on
the MEGA65), and the read port four: the read address goes to a register in
each group, which drives the 8 BRAMs of the group, then the BRAMs are read,
then each group selects the pixel (the block in the group and the position in
the word), and then the pixel is selected from the groups. Before the MEGA65
had 320 blocks, the read address went directly to all the BRAMs, the word was
selected from all the blocks in one clock cycle, and the pixel from the word
in the next, i.e. three clock cycles of latency. With 320 blocks at 108 MHz,
the route from the pixel counters to all the BRAMs alone took 8.2 ns of the
9.26 ns. `vga` gives `disp` and `overlay` the pixel counters delayed by one
clock cycle, so they still see three clock cycles. The
display memory has a small self-checking testbench
([`sim/disp_mem_tb.vhd`](sim/disp_mem_tb.vhd)). It writes to a few words
in each block, back-to-back both in different blocks and in the same block,
and reads all their pixels back on the read port. It checks that each value is
written to the right block and address, and is in the right position in the
word, that a second write overwrites the first, that nothing is written when
the write enable is low, and that the read latency is exactly four clock
cycles. It does this for 1 and 4 pixels in each word with 128 blocks, and
for 4 pixels with 320 blocks, 21 bits of address and no registers for the
blocks, where it also checks that writes beyond the last block are
ignored. On reset, the whole memory is filled
with the value 0x055, which takes `G_NUM_BLOCKS`*4096/`G_PIXELS` clock
cycles. This is checked with a memory of only 8 blocks.

The rest of this section describes `main`.

**Continuous calculation.** A new picture is started as soon as the previous one
is finished. When the signal done\_o from the dispatcher goes high, the signal
active is cleared for one clock cycle, and then it is set again together with a
pulse on start. The dispatcher clears done\_o when it sees the start, so done\_o
is ignored while start is high.

**The view.** The view is given by the position of the top left corner of the
picture (startx, starty), and the size of a pixel (stepx, stepy). The initial
view has the real axis from -1.6667 to 1.0, and the imaginary axis is
centred on 0, with the same aspect ratio as the picture, so the pixels are
square: from -1.0 to 1.0 for 640x480 (4:3), and from -1.0667 to 1.0667 for
1280x1024 (5:4) on the MEGA65. The pixel size is the size of the view divided
by the number of columns and rows.

The view is controlled by the module [`src/main/view.vhd`](src/main/view.vhd). It is
updated at a fixed rate, which is given by a counter of 23 bits in `main.vhd`.
At 150 MHz (and at 148.97 MHz on the MEGA65) this is once every 56 ms, i.e.
about 18 times per second. At
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
the job modules calculate by adding stepx and stepy, would wrap around, and
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
(the generic `G_CLK_FREQ` of `main`, set by the top level: 150,000,000 Hz, or
188,235,294 Hz on the MEGA65) by the value of the counter, and converts the
result to decimal. The picture is recalculated continuously, so the frame rate
is updated after every picture (about 432 times per second for the initial
view).
A single-cycle division would be far too slow for the MAIN clock, so both
steps are done one bit per clock cycle: a restoring division, with one
subtraction for each of the 28 bits of the quotient, and then the double
dabble algorithm to convert the quotient to 8 decimal digits (for each bit, 3
is added to each digit which is 5 or more, and then everything is shifted left
by one bit). This takes 58 clock cycles, much less than a picture, and the
widest addition is 29 bits. A frame rate above 99999999 would show as
99999999, but that would need a picture of fewer than 2 clock cycles. The
counter is 27 bits wide, so it wraps around after 2^27 clock cycles (0.89 s
at 150 MHz), but a picture takes far less than that: even if every pixel
needed the maximum count, the model (see [Timing](#timing)) gives 2040977
clock cycles (13.6 ms, i.e. 73 pictures per second) for the picture.

The digits of the display share the segment signals, so
[`src/main/seg.vhd`](src/main/seg.vhd) shows them one at a time, each for 2^14 clock
cycles, i.e. all 8 digits are refreshed every 0.70 ms (1.4 kHz). The
segments and the digit enables (anodes) are active low. The decimal point is
not used.

The same frame rate is shown in the top right corner of the VGA output, by
[`src/vga/overlay.vhd`](src/vga/overlay.vhd), in white on black, with the
leading zeros not shown (the picture is shown there instead). The digits are
16x32 pixels, from the [Spleen](https://github.com/fcambus/spleen) font
(BSD 2-Clause license, see [`font/LICENSE.spleen`](font/LICENSE.spleen)). The
script [`font/gen_font_pkg.py`](font/gen_font_pkg.py) converts the font to the
table in [`src/vga/font_pkg.vhd`](src/vga/font_pkg.vhd), 32 rows of 16 bits
for each digit. The frame rate (32 bits of digits and 8 bits of blanking) is
calculated in the MAIN clock domain, so it is moved to the VGA clock domain:
`main` changes a toggle signal each time the frame rate changes. This is
synchronized with two registers in the top level (`p_fps_cdc` in
[`src/nexys4ddr.vhd`](src/nexys4ddr.vhd)), and when it changes, the frame
rate is copied, so `overlay` only gets signals in the VGA clock domain. The
frame rate changes only at the end of a picture, so it is constant for much
longer than the synchronizer takes (a few VGA clock cycles), and it is never
copied while it changes. The constraint in [`nexys4ddr.xdc`](nexys4ddr.xdc)
and [`mega65-r6.xdc`](mega65-r6.xdc) (`set_max_delay -datapath_only`) makes
sure that it arrives before the toggle signal, and excludes these paths from
the normal timing between the two clocks. The new
value is shown from the next frame on, so a frame never shows two values.
The overlay is a pipeline of five stages after the pixel counters: the position
in the overlay, the digit, the row of the font, the pixel of the row, and then
the colour, which replaces the output of `disp`. This adds one clock cycle of
latency to all the VGA outputs.

The testbench [`sim/fps_tb.vhd`](sim/fps_tb.vhd) is self-checking. It gives
the frame rate module a number of picture times (the extremes, the values
around a change of the frame rate, e.g. 199 and 200, and random values), and
checks the digits and the blanking against the integer division, and that the
display shows the same number: every digit that is not blanked is switched on
with the right segments during a refresh cycle, the blanked digits are never
switched on, and at most one digit is on at a time. It also checks that a new
picture time during a calculation is ignored.

The testbench [`sim/overlay_tb.vhd`](sim/overlay_tb.vhd) checks the colour of
every pixel of three frames of the VGA output (with a different value for each
pixel), with no frame rate (the initial value), 4 digits and 8 digits. The
frame rate is changed in the middle of the overlay, and the new value must
only be shown in the next frame. It prints the overlay of the last frame.

**Other inputs.** The switches 0 and 1 select the colour palette, see
[Colours](#colours). They are used in the VGA clock domain (in `vga`), not in
`main`. The switches 3 to 7 are not used.

## Colours
The display memory holds the count of each pixel (9 bits). The VGA output has
8 bits of colour, in the format RRRGGGBB (3 bits red, 3 bits green, and 2 bits
blue). The points in the set (count 511) get the colour of the set. For the
other counts, the lower 8 bits of the count (the value) are converted to the
colour by one of four palettes in [`src/vga/palette_pkg.vhd`](src/vga/palette_pkg.vhd),
selected by switches 0 and 1 (switch 1 is the high bit):
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
the timing and the polarity of the sync signals, and then the colour of every
pixel of a frame, with a different value for each pixel, and a different
palette for every 120 lines. This also checks the address of each pixel. It
does this for both video modes, each with the address layout of its board,
and for 640x480 with 480 addresses for each picture column (not a power of
two).

**Video modes.** The resolution and the timing of the VGA output are given by
a video mode, which is a record in
[`src/vga/video_pkg.vhd`](src/vga/video_pkg.vhd): the number of visible
pixels, the front porch, the sync pulse and the back porch, for each line and
for each frame, and the polarity of the sync pulses, from the VESA standard.
There are two: 640x480 at 60 Hz (pixel clock 25.175 MHz, which works fine with
25 MHz, and negative sync pulses), used on the Nexys 4 DDR, and 1280x1024 at
60 Hz (pixel clock 108 MHz, 1688 pixels in each line, 1066 lines, and positive
sync pulses), used on the MEGA65. The top level gives the video mode to `vga`
and the size of the picture to `main`, and sets the VCO and the divider of the
VGA clock in `clk_rst` (1200 MHz divided by 48, or 1080 MHz divided by 10). The pixel counters have 11 bits, for
up to 2048 pixels in a line. `vga` calculates the address of the pixel from
the pixel counters (the column times `G_COL_STRIDE` plus the row, in LUTs),
which is only wires on the Nexys 4 DDR.

## Timing
A counter measures the time it takes to generate the picture, which is shown
as a frame rate on the 7-segment display and on the VGA output, see
[The top level](#the-top-level).
Earlier versions showed this time on the LEDs instead, in units of 2^11 clock
cycles, and also (selected with a switch) the total amount of time the job
modules were waiting to write to the display memory, when the waiting-time statistic
was enabled. The LEDs are no longer used, and the counters for the waiting
time have been removed.

The numbers measured on the board, with the main clock at 174.55 MHz, the
waiting-time statistic built in, and the initial view, were:
* The time for the picture: 0x01D8 = 472, i.e. 472\*2^11 clock
  cycles, which was 5.5 ms at 174.55 MHz. This value is steady. The same
  number of clock cycles was measured with the main clock at 140.625 MHz
  (6.9 ms), before the clock was raised (see
  [Resources and timing closure](#resources-and-timing-closure)). This was
  before the periodicity detection (see [Iterator](#iterator)), and before
  the schedulers and the done flag were pipelined (see
  [Dispatcher](#dispatcher)).
* The waiting time of all the job modules: 0x720C = 29196,
  i.e. 29196\*2^11 clock cycles in total, which is about a quarter of the
  time of each job module. Before the value was averaged over 64 pictures,
  the lowest bits changed from picture to picture (about 0x721F = 29215 was
  measured), because each wait counter was truncated to units of 2^11 clock
  cycles before the sum.

Both values agreed with the model [`sim/model.py`](sim/model.py) at the time,
which estimated the time for the picture from the number of iterations of each
pixel, as follows. A job module uses 3 clock cycles per iteration, plus 7
clock cycles to start the iterator and to deliver the result, i.e. 3n+7 clock
cycles, where n is the number of iterations done when the iterator stops: the
count for a pixel that escapes, 510 for a pixel that reaches the maximum
count, and the iteration after the match for a pixel where a cycle is found.
Then the result must be accepted by the dispatcher. The scheduler for the
results was then the same round-robin scheduler as for the jobs, which checked
each job module once every 240 clock cycles, so the time from one result of
a job module to the next was always a multiple of 240 clock cycles. This was
checked in simulation. So:
* A pixel with a count up to 77 took 240 clock cycles, i.e. the iterator was
  idle for most of the time, waiting for the result to be accepted.
* A pixel in the set that does not reach a cycle took 3\*510+7 = 1537 clock
  cycles, which was rounded up to 1680 clock cycles. Before the periodicity
  detection, this was the case for all the pixels in the set.

Without the periodicity detection, the iterator needed 460 clock cycles per
pixel on average for the initial view (the average count is 151), but each
pixel took 652 clock cycles on average, including the waiting. A single
picture column through the middle of the set took up to 0.73 million clock
cycles, so these picture columns decided the total time. The model gave
472\*2^11 clock cycles for the picture, the same as measured.

With the periodicity detection, the iterator needs 132 clock cycles per pixel
on average, and each pixel took 316 clock cycles on average, including the
waiting. Most of the pixels took the minimum of 240 clock cycles, and the
longest picture column took 0.27 million clock cycles. When each job was a
whole picture column, the model gave 551040 clock cycles (269\*2^11) for the
picture, i.e. 2.9 ms at 188.24 MHz, 1.75 times faster than without the
detection (about 341 pictures per second).

With 640 jobs and 240 job modules, each job module got fewer than three
jobs, so the work was not shared evenly at the end of the picture: if the
work was spread evenly over the job modules, each of them would need
404875 clock cycles. With jobs of 120 rows (2560 jobs), the longest job took
0.11 million clock cycles, and the model gave 418560 clock cycles
(204\*2^11) for the picture, i.e. 2.22 ms at 188.24 MHz, 1.32 times faster
(about 450 pictures per second). The model gave 465840 clock cycles for jobs
of 240 rows, and 413040 clock cycles for jobs of 60 rows. Eight other views
(zoomed in at different places) were 1.07 to 1.31 times faster in the model
with jobs of 120 rows than with whole picture columns.

Without the periodicity detection, the model gave a total waiting time of
59,179,719 clock cycles, i.e. 28896\*2^11 clock cycles, or about 193 clock
cycles per pixel on average. The wait counter of a job module counted 2
clock cycles more for each pixel. With these 2 clock cycles for each of the
307200 pixels, the expected value on the LEDs was 29196 (0x720C), exactly the
measured value. The wait counters have been removed from the design, so the
model was then the way to get this value. With the periodicity detection
(and the round-robin scheduler for the results), the wait counters would have
shown about 27981.

The wait counter counts from 3 clock cycles after the result is ready until
the clock cycle before the acknowledge reaches the job module. When the
acknowledge was delayed by one more clock cycle (by the registers in the
groups, see [Dispatcher](#dispatcher)), the value on the LEDs did not change:
the job module then starts the next row one clock cycle later, so its next
result is ready one clock cycle later, and waits one clock cycle less for the
scheduler. The waiting time counted for a pixel is the time from one accepted
result of the job module to the next, minus the time the iterator needs
for the pixel, minus a fixed number of clock cycles, and this does not depend
on the delay of the acknowledge. Neither did the time for the picture, because the time from
one result of a job module to the next was still rounded up to the same
multiple of 240 clock cycles.

Without the waiting, the picture would take about 0.9 ms (if the work was
spread evenly over the job modules). So the time for the picture was
mostly decided by the round-robin scheduler for the results, which accepted a
result from each job module only once every 240 clock cycles.

Similar values (472\*2^11 clock cycles for the picture, and 28642\*2^11 clock
cycles of waiting) were measured earlier, with an iterator which did not detect
all overflows and which calculated x+y and x-y in 18 bits (see
[Overflow](#overflow)), and with a main clock of 150 MHz. The time for the
picture did not change, because it is decided by the picture columns through
the middle of the set, where most of the pixels reach the maximum count.

The display memory can take one result per clock cycle, so a picture takes
at least 307200 clock cycles (1.63 ms). The round-robin scheduler gave each
job module an equal share of this, one result every 240 clock cycles, also
when the other job modules had no result ready. The scheduler for the
results now accepts a result from any job module of a group that has one
ready, visiting one group in each clock cycle (see [Dispatcher](#dispatcher)).
The waiting time of a pixel then depends on the other job modules, so the
model now simulates the dispatcher one clock cycle at a time
(`picture_cycles()` in `sim/model.py`). It uses the time 3n+7 above for each
pixel, from the clock cycle before the previous result was accepted, and it
includes the round-robin scheduler for the jobs. For the initial view it gives
347123 clock cycles for the picture, i.e. 1.84 ms at 188.24 MHz, the main
clock at the time (see [Resources and timing closure](#resources-and-timing-closure)).
At the 150 MHz used now it is 2.31 ms, so the 7-segment display should show
about 432 pictures per second. The same
simulation with the round-robin scheduler for the results gives 2.24 ms
(0.02 ms more than above, because it includes the time to give out the jobs),
so the new scheduler is 1.21 times faster. The display memory is now written
in 88% of the clock cycles, and the job modules wait 127 clock cycles per
pixel on average. Eight other views were 1.11 to 1.21 times faster with the
new scheduler. Registering the ready flags in the groups (see
[Dispatcher](#dispatcher)) makes no measurable difference: before, the model
gave 347682 clock cycles, and a simulation of a complete picture with
`main_tb` took 347110 clock cycles from the start to the last write to the
display memory, 0.2% less than the model, with all the pixels the same as in
the model. None of this has been measured on the board yet.

Storing a result in each job module, so the iterator could continue with
the next row while it waits, was considered too. With the round-robin
scheduler for the results it would have made the initial view only 4% faster
(and two results no better than one), because each job module could still
deliver only one result every 240 clock cycles.

**Several pixels in each write.** With the scheduler for the results above,
the time for the picture is mostly decided by the write port of the display
memory, which takes one result per clock cycle. The BRAMs can be written in
words of 36 bits instead of 9, i.e. four pixels, with the same number of BRAMs
(see [The top level](#the-top-level)). So each result can be four consecutive
rows of a picture column (the generic `G_PIXELS`), which the job module
calculates one after the other, keeping the counts of the first three (see
[Jobs](#jobs)). A result then takes the sum of the times of its four
rows (less 4 clock cycles for each row after the first, because the iterator
starts the next row itself), and the dispatcher writes up to four pixels per
clock cycle. The model gives these times for the initial view at 640x480 (in
clock cycles, and frames per second at 188.24 MHz in brackets):

| Job modules | 1 pixel in each write | 2 pixels | 4 pixels
| -------------- | --------------------- | -------- | --------
| 240            | 347123 (542)          | 241674 (779) | 209248 (900)
| 450            | 339741 (554)          | 203477 (925) | 161909 (1163)

A dispatcher where any
result can be written, with up to four writes per clock cycle, would take
about 152000 clock cycles with 450 job modules (estimated with a simpler
model), so four pixels in each write
gets most of what more writes per clock cycle can give. The rest is mostly
the end of the picture, when the last jobs finish one after the other, and
the iterators alone would need 89954 clock cycles (0.48 ms) for the initial
view with 450 job modules, if the work was spread evenly. Several
independent dispatchers, each with its own BRAMs (e.g. for the even and the
odd picture columns), would give about the same, but with all the control
logic duplicated. For views where the iterators need more time per pixel, the
gain is smaller: a view of Seahorse Valley (0.08 wide, centred near
-0.75+0.15i) takes 618735 clock cycles with one pixel and 517626 with four
pixels in each write (with 450 job modules), 1.20 times faster.

Four pixels in each write are used on the MEGA65 (see [MEGA65 R6](#mega65-r6)).
The Nexys 4 DDR uses one pixel in each write. A run of `make nexys4ddr` with
four pixels in each write fits and meets timing at 188.24 MHz, but only just:
it uses 15,459 slices (97.5%), 44,737 LUTs and 55,538 registers, and has
+0.012 ns of setup slack and +0.005 ns of hold slack (in an iterator). The
model gives 209248 clock cycles for it (1.39 ms at 150 MHz, about 716 pictures
per second). A simulation
of a complete picture with `main_tb` and the design of the MEGA65 (then
640x480) took 161878
clock cycles from the start to the last write to the display memory, 0.02%
less than the model, with all the pixels the same as in the model. The
simulation took about an hour.

## Resources and timing closure
The numbers below come from a successful run of `make nexys4ddr` (Vivado 2025.1,
part xc7a100tcsg324-1, i.e. speed grade -1), which meets timing with a
150 MHz main clock.

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 240      | 240       | 100
| Block RAM        | 128 RAMB36 + 2 RAMB18 | 135 RAMB36 | about 96
| Slices           | 14,505   | 15,850    | 92
| LUTs             | 42,049   | 63,400    | 66
| Registers        | 43,610   | 126,800   | 34
| Clock buffers    | 3 BUFG, 1 MMCM | |

The resource numbers are from `report_utilization` on the routed design
(`nexys4ddr.dcp`), and the available numbers are the totals for the XC7A100T.
Most of the slices are used, even though only 66% of the LUTs are used.

The "Report Cell Usage" table in `vivado.log` gives the cell counts after
synthesis instead: 55,903 LUT cells (LUT1 to LUT6) and 43,628 registers (FDRE
and FDSE cells). The number of LUT cells is larger than the number of LUTs
used, because two small LUT cells can share one LUT (the placer does this,
"LUT Combining"). The number of registers is about the same after routing, because
timing is met before `phys_opt_design`, so it does nothing. At 188.24 MHz
there were 45,018 registers after routing (and 43,187 after synthesis),
because the physical optimization replicated registers with a high fanout,
and moved some of them (retiming).

The periodicity detection (see [Iterator](#iterator)) uses about 5,500 LUT cells
and 8,900 registers (36 registers for the saved values in each iterator), and
increased the slices used from 81% to 93%. A first version, which cleared the
saved values at the start of each point, used about 4,100 LUT cells more.

With the waiting-time statistic built in, and with only the lower
8 bits of the count in the display memory, the design used 53,386 LUT cells and
44,493 registers after synthesis, and 40,542 LUTs, 46,345 registers, and 14,789
slices (93%) after routing, and the setup slack at 174.55 MHz was +0.094 ns. So
the statistic costs about 4,200 LUT cells and 10,200 registers, mostly for the
27-bit wait counter in each job module and the chain of adders in the
dispatcher.

Before the post-adder of the DSP was used (see [Multiplier](#multiplier)), the
design used 61,895 LUT cells and 53,885 registers after synthesis, and 49,087
LUTs, 53,960 registers, and 15,402 slices (97%) after routing. The timing
slack was about the same (+0.116 ns), because the critical paths were not in
the iterators.

The registers that shorten the routes to the job modules and to the BRAMs
(see [Dispatcher](#dispatcher) and [The top level](#the-top-level)) use about
4,600 registers and 500 LUT cells. Before they were added, the setup slack was
+0.104 ns.

The display memory has 2^19 entries of 9 bits (the count), i.e. 128 blocks of
36 kbit BRAM, each used as 4096 entries of 9 bits (with the parity bits), as
expected. The registers of the read address in each group of 8 blocks (see
[The top level](#the-top-level)) use about 400 registers, against the build
before them (14,508 slices, 42,035 LUTs and 43,217 registers, with +0.355 ns
of setup slack). The two RAMB18s are used by the dispatcher, for the tables
`job_addr_r` and `job_blk_r` that hold the picture column and the block of the
job of each job module (240 entries of 10 bits, and of 2 bits).

The jobs of 120 rows (see [Dispatcher](#dispatcher)) did not use more
resources: before them, the design used 55,536 LUT cells and 43,656 registers
after synthesis, and 42,158 LUTs, 46,314 registers, and 14,764 slices (93%)
after routing, with a setup slack of +0.045 ns. The job modules need fewer
bits for the row (7 instead of 9), which saves more than the dispatcher
needs for the blocks.

The scheduler for the results (see [Dispatcher](#dispatcher)) uses about
1,000 LUT cells more than the round-robin scheduler did. Before it, the design
used 54,492 LUT cells and 42,708 registers after synthesis, and 41,284 LUTs,
44,562 registers, and 14,641 slices (92%) after routing, with a setup slack of
+0.103 ns.

The timing after routing is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.343 ns (TNS 0)
| Hold (WHS)  | +0.014 ns (THS 0)

These are the values from `report_timing_summary` on the routed design
(`nexys4ddr.dcp`), after the post-route `phys_opt_design`.

The timing is met for all clocks. The 150 MHz main clock (period 6.67 ns) is
generated from the 100 MHz input clock by the MMCM: it is multiplied by 12,
which gives 1200 MHz (the maximum for speed grade -1), and divided by 8. The
main clock uses the output CLKOUT0 of the MMCM, because it is the only output
with a fractional divider. The MMCM also generates the 25 MHz VGA clock
(divided by 48). On the MEGA65 the VCO is 1080 MHz instead, see
[MEGA65 R6](#mega65-r6). The constraints in `nexys4ddr.xdc` are the 100 MHz input
clock, and a maximum delay (`set_max_delay -datapath_only`) for the paths from
the MAIN clock to the VGA clock, which only carry the frame rate and its toggle
signal to the synchronizer in the top level (see [The top level](#the-top-level)). Apart from these,
the two clocks only meet in the display memory, which has a separate clock for
each port.

At 150 MHz, the worst path is a route from the registers of a group in the
dispatcher (`grp_cx_r`) to a job module (`res_cx_r`), with no logic, and
92% of its delay in the routing. At 188.24 MHz (the main clock of the Nexys 4
DDR until it was lowered to 150 MHz, see below), the critical paths are in the
iterators, and in the job modules around them:
* From the output of the DSP (which is not registered, see
  [Multiplier](#multiplier)) to the overflow flags.
* From x\_r and y\_r through the additions x+y and x-y and the selection of
  the inputs of the multiplier to the input registers of the DSP, with 6 or 7
  levels of logic.
* The acknowledge of the results (`res_ack_r`) to the row in the job
  modules, and the routes from the registers in the groups to the job
  modules.
* The state machine of the iterator (from cnt\_r and state\_r), and the
  periodicity detection (to match\_r and the saved values).
* The scheduler for the results: the round-robin selection in a group, from
  the registered ready flags (`req_r`) to the candidate of the group
  (`cand_r`), with 5 levels of logic. This was the worst path in the last
  build at 188.24 MHz (+0.092 ns). Before the ready flags were registered, the path started
  at the acknowledge (`res_ack_r`) in the dispatcher, with 6 levels of logic,
  and had +0.037 ns of slack.
* The next row in the job modules (to `res_cy_r`, whose clock enable
  depends on the result of the iterator).
To go faster, the iterator would have to be changed, e.g. by registering the
output of the DSP, which would change the three clock cycles of an iteration.

At 177.78 MHz, before the next row in the job modules, the schedulers and
the done flag were pipelined (see [Dispatcher](#dispatcher)), these were the
critical paths, with up to 22 levels of logic (the done flag).

At 140.625 MHz, the critical paths were first the routes from single registers
to all 240 job modules (the job, the reset, and the index of the job
module whose result is accepted) or to all 128 BRAMs (the write address),
before the registers in the groups and the blocks were added, and before that
the selection of the job module in the schedulers, and the iterators (from
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

Then the next row in the job modules, the schedulers and the done flag were
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
same frequency, had +0.103 ns of setup slack, and the build with the scheduler
for the results had +0.037 ns.

The frame rate overlay on the VGA output (see [The top level](#the-top-level))
uses about 100 LUT cells and 130 registers after synthesis, and no block RAM
(the font table is in LUTs). The build with it has +0.006 ns of setup slack.
The worst path is in `view` (from `zoomx` to the clock enable of `dy`), which
the overlay does not change, so this is the variation from one run to the
next. The 40 paths from the MAIN clock to the VGA clock (the frame rate and
its toggle signal) had +8.19 ns of slack against the maximum delay of 10 ns,
and `report_cdc` reports all of them as safe.

Registering the ready flags in the scheduler for the results (see
[Dispatcher](#dispatcher)) uses about 240 registers more (one for each job
module), and raised the setup slack to +0.064 ns. The paths from the MAIN
clock to the VGA clock then had +8.41 ns of slack.

The synchronizer for the frame rate was then moved from `overlay` to the top
level. This is the same logic, and the cell counts after synthesis did not
change. The build with it has +0.092 ns of setup slack, and the 40 paths from
the MAIN clock to the VGA clock have +8.39 ns of slack, and are all reported
as safe by `report_cdc`.

The main clock of the Nexys 4 DDR was then lowered from 188.24 MHz to 150 MHz
(1200 MHz divided by 8 instead of 6.375), and the MEGA65 keeps 188.24 MHz.
Even if every pixel needed the maximum count, the model gives 2040977 clock
cycles for the picture, i.e. 73 pictures per second at 150 MHz, still well
above the 60 Hz of the VGA output. The setup slack rose from +0.092 ns to
+0.355 ns, which leaves room for more logic. The aim was a faster build, but
the build took the same time as before: the run time is decided by the
directives in `mandelbrot.tcl`, not by the slack. Only the two runs of
`phys_opt_design` do nothing now, because timing is already met, and they
took only about 10 seconds before.

The display memory then got a register of the read address in each group of
8 blocks (for the MEGA65 at 1280x1024, see [MEGA65 R6](#mega65-r6)), which
makes the read latency four clock cycles. The build with them has +0.343 ns
of setup slack, with the worst path of the same kind, and the 40 paths from
the MAIN clock to the VGA clock are all reported as safe by `report_cdc`.

The complete run of `make nexys4ddr` takes about 6.5 minutes (synthesis about 2.5
minutes, placement about 1.75 minutes, routing about 1 minute), on a machine
with 8 threads.

### MEGA65 R6
The MEGA65 R6 has an XC7A200T with speed grade -2 (part xc7a200tfbg484-2). The
VGA output is 1280x1024 at 60 Hz, with a 108 MHz pixel clock, and the design
uses 256 job modules and four pixels in each write to the display memory,
with a 148.97 MHz main clock (see [`src/mega65_r6.vhd`](src/mega65_r6.vhd)
and *Video modes* in [Colours](#colours)). The MMCM multiplies the 100 MHz
input clock by 54/5, which gives a VCO of 1080 MHz, the only VCO frequency
that gives 108 MHz exactly (divided by 10); the main clock is the VCO divided
by 7.25. The display memory has 1280x1024 pixels in 320 BRAMs, with 21 bits
of address (the column followed by the row), and no registers for the write
port of each block (see [The top level](#the-top-level)). The jobs are 64
rows, because 1024 is not a multiple of 120. A run of the same steps as
`make mega65-r6` gives:

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 256      | 740       | 35
| Block RAM        | 320 RAMB36 + 2 RAMB18 | 365 RAMB36 | 88
| Slices           | 19,305   | 33,650    | 57
| LUTs             | 49,250   | 134,600   | 37
| Registers        | 52,144   | 269,200   | 19

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.002 ns (TNS 0)
| Hold (WHS)  | +0.041 ns (THS 0)

After synthesis there are 78,846 LUT cells and 52,172 registers. The worst
setup path of the main clock is a route from the registers of a group in the
dispatcher (`grp_cx_r`) to a job module (`res_cx_r`), with no logic, and
95% of its delay in the routing. The VGA clock has +0.141 ns of setup slack:
its worst path is from the read address register of the display memory to
the copy of the pixel position in a group, also only routing (8.5 ns). The
40 paths from the MAIN clock to the VGA clock are reported as safe by
`report_cdc`. The colour and sync outputs to the video DAC are registered in
the IOBs.

The routing is close to its limit. The router first leaves about 10,000 to
14,000 nodes with overlaps (more nets than routing resources), and then needs
several iterations to resolve them. An earlier run of the same design took 10
minutes for the routing and had +0.252 ns of setup slack; the run above took
61 minutes, and only met timing after the post-route `phys_opt_design`. With
450 job modules the router left 29,614 overlaps, and did not finish
within an hour. The cause is the display memory: its 320 BRAMs (88%) are
spread over the whole FPGA, and so are the routes of the write data and of
the read address, while the 800x600 design below only used 128 BRAMs (35%).
With 64 job modules the routing took 1.5 minutes. The frame rate goes down
with fewer job modules: the model gives 203 pictures per second for the
initial view with 256 job modules (4.91 ms), against 57 with 64. If every
pixel needed the maximum count, the picture would take 7885023 clock cycles
(53 ms, 18 pictures per second).

The main clock was 187.83 MHz (1080 MHz divided by 5.75) at first, but with
450 job modules it failed timing by about 0.15 ns after the placement, and
the slices were 92% used. Leaving out the registers of the write port of each
block (about 15,000 registers) and lowering the main clock to 180 MHz still
left one path failing by 0.247 ns, so the main clock was lowered to 148.97
MHz, and then the number of job modules. The registers of the read
address in each group were added when the VGA clock had only +0.207 ns of
setup slack with 64 job modules: the route from the pixel counters to all
320 BRAMs took 8.2 ns of the 9.26 ns. With them the slack was +0.620 ns.

The 800x600 design used 450 job modules with a 188.24 MHz main clock
(1200 MHz divided by 6.375), and a display memory of 2^19 pixels (128 BRAMs),
where each picture column had 600 addresses. A run of `make mega65-r6` gave
29,964 slices (89%), 81,646 LUTs, 93,443 registers, +0.186 ns of setup slack
and +0.013 ns of hold slack. After synthesis there were 107,980 LUT cells and
93,411 registers. The worst setup path was in the tree of registers of the
display memory (from the data register to the register of a group), and the
worst hold path was from the data register of a block of the display memory
to its BRAM. The VGA clock had +6.7 ns of setup slack (of 25 ns). The run
took about 14 minutes (synthesis 4.5 minutes, placement 4.5 minutes, routing
3 minutes).

The first build with 800x600 failed timing by 0.226 ns, from the table
`job_addr_r` (a BRAM) through the multiplication by 600 in the dispatcher,
and used a DSP for the multiplication in `vga`, because Vivado ignored the
attribute `use_dsp` on the sum. The multiplication was moved one clock cycle
later (see [Dispatcher](#dispatcher)), and the attribute put on the product.
The 800x600 picture costs about the same resources as 640x480 did (30,114
slices, 81,630 LUTs, 93,491 registers, and +0.136 ns of setup slack). A run of
`make nexys4ddr` with the same version (still 640x480) gave +0.009 ns of setup
slack (in an iterator) and +0.021 ns of hold slack, with 14,790 slices, 42,131
LUTs and 46,431 registers. Two earlier runs of it stopped with a segmentation
fault in Vivado (in the routing and in the `phys_opt_design` after it), which
also happened once before with `make mega65-r6`; running it again helped.

With 640x480 and one pixel in each write, the model gave 339741 clock cycles
for the initial view with 450 job modules, i.e. 1.80 ms at 188.24 MHz
(about 554 pictures per second), only 2% faster than with 240 job modules.
The display memory was then written in 90% of the clock cycles, so the time
for the picture was decided by the write port of the display memory (at least
307200 clock cycles, see [Timing](#timing)), not by the number of job
modules. With four pixels in each write, the model gave 161909 clock cycles,
i.e. 0.86 ms (about 1163 pictures per second), 2.1 times faster. This cost
16,165 registers (27 bits in each job module for the counts of the first
three rows, and the wider data in the dispatcher and in the tree of registers
of the display memory), 4,050 LUTs, and 3,881 slices, against the build with
one pixel in each write. The setup slack was +0.178 ns and the hold slack
+0.023 ns with one pixel in each write.

With 800x600 (480,000 pixels, 56% more), the model gave 248969 clock cycles
for the initial view, i.e. 1.32 ms (about 756 pictures per second). With one
pixel in each write it would be 512370 clock cycles (2.72 ms), and with two
299485 (1.59 ms). Even if every pixel needed the maximum count, the picture
would take 1663271 clock cycles (8.8 ms). A simulation of a complete 800x600
picture with `main_tb` took about 248920 clock cycles from the start to the
last write to the display memory, 0.02% less than the model, with all the
pixels the same as in the model. The simulation took about 1.5 hours.

With 1280x1024 (1,310,720 pixels, 4.3 times as many as 640x480) and 256
job modules, the model gives 732009 clock cycles for the initial view,
i.e. 4.91 ms at 148.97 MHz (about 203 pictures per second). With one pixel
in each write it would be 1454290 clock cycles (9.76 ms). Jobs of 32 to 128
rows give 199 to 203 pictures per second. A simulation of a partial
1280x1024 picture with `main_tb` (then with 450 job modules: all 1280
columns, rows 0 to 151, 155,832 pixels) gave the same pixels as the model.

All 240 DSPs running at 150 MHz gives a peak of 36 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 24 billion multiplications per second. On the MEGA65
(256 DSPs at 148.97 MHz) it is about 25 billion.
