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
 +- dispatcher                  src/dispatcher.vhd
 |   +- scheduler               (i_scheduler, selects the column module to receive a job)
 |   +- column  (x 240)         src/column.vhd (the column modules)
 |   |   +- iterator            src/iterator.vhd
 |   |       +- mult_macro      (Xilinx unimacro, uses one DSP)
 |   +- scheduler               (i_scheduler_res, selects the column module whose result is accepted)
 +- pix                         src/pix.vhd (pixel counters)
 +- disp_mem                    src/disp_mem.vhd (display memory)
 +- disp                        src/disp.vhd (VGA output)
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
before $|z|$ grows beyond 2 (or a maximum iteration count is reached) is used
to colour the pixel.

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
The built-in DSP provides an 18-bit signed multiplier. This generates a 36-bit
result in 4.32 bit representation. The actual multiplier is defined in a
special Xilinx unimacro, and there is a testbench specifically for the
multiplier ([`sim/mult_macro_tb.vhd`](sim/mult_macro_tb.vhd)).

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

The iterator has been heavily optimized to use only a single multiplier, and to
pipeline the calculations. Each iteration takes three clock cycles, and is
controlled by a simple state machine:
* In the first clock cycle (ADD\_ST), the multiplier is given the values of x
  and y, and simultaneously, the values x+y and x-y are calculated.
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

The values x+y and x-y are still calculated in 18 bits, so they wrap around if
they are outside the range -2 to 2. This is not detected, and can give a
different count, compared with an exact calculation, for points where this
happens before the value of x or y is out of range.

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

## Timing
Counters measure the total time it takes to generate the picture as well as the
total amount of time the iterators are waiting to write to display memory.

Note: The numbers in this section were measured on the board with an earlier
version of the iterator, which did not detect all overflows (see
[Overflow](#overflow)), and with a main clock of 150 MHz. The number of clock
cycles has not been measured again since then, and may be lower now, because
some points are now detected as overflowing earlier. The times below have been
recalculated for the current main clock of 140.625 MHz.

The total time taken is 472\*2^11 clock cycles, which at a frequency of 140.625
MHz becomes 6.9 milliseconds.

The average waiting time for each iterator is 28642/240 \* 2^11 clock cycles,
which is 1.7 milliseconds. So a quarter of the time is spent waiting. However,
at this processing speed it really doesn't matter.

Another way of looking at this is that each iterator is using 472\*2^11 clock
cycles, so a total of 232 million clock cycles. The average amount per pixel is
then obtained by dividing by 640 and by 480, which gives 755 clock cycles, or
in other words 252 iterations per pixel.

## Resources and timing closure
The numbers below come from a successful run of `make vivado` (Vivado 2025.1,
part xc7a100tcsg324-1, i.e. speed grade -1), which meets timing with a
140.625 MHz main clock.

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 240      | 240       | 100
| Block RAM        | 128 RAMB36 + 1 RAMB18 | 135 RAMB36 | about 95
| LUTs             | about 52,000 | 63,400 | about 82
| Registers        | about 53,300 | 126,800 | about 42
| Clock buffers    | 3 BUFG, 1 MMCM | |

The resource numbers are the cell counts after synthesis, taken from
`vivado.log`, and the available numbers are the totals for the XC7A100T. The
design uses memory with 2^19 entries of 9 bit, i.e. 128 blocks of 36 kbit
BRAM, as expected.

The timing after routing is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.029 ns (TNS 0)
| Hold (WHS)  | +0.023 ns (THS 0)

These are the estimated timing summaries printed by Vivado during routing (the
post-route physical optimization found no setup violations, and did not change
the netlist).

The timing is met for all clocks. The 140.625 MHz main clock (period 7.11 ns)
is generated from the 100 MHz input clock by the MMCM (multiplied by 11.25 and
divided by 8), and the only constraint in `mandelbrot.xdc` is the 100 MHz input
clock. The MMCM also generates the 25 MHz VGA clock (divided by 45).

The slack is small, so the design is close to the limit of what this device and
this flow can achieve. The critical paths are in the dispatcher: the selection
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

The complete run of `make vivado` takes about 10 minutes (synthesis about 2
minutes, routing about 3 minutes), on a machine with 8 threads.

All 240 DSPs running at 140.625 MHz gives a peak of 34 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 22 billion multiplications per second.
