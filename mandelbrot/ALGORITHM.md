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
The modules are instantiated as follows (the entity name is given where it
differs from the file name):
```
mandelbrot                      src/mandelbrot.vhd (top level)
 +- clk_wiz_0_clk_wiz           src/clk.vhd (MMCM and clock buffers)
 +- dispatcher                  src/dispatcher.vhd
 |   +- scheduler               (i_scheduler, selects the column to receive a job)
 |   +- column  (x 240)         src/column.vhd
 |   |   +- iterator            src/iterator.vhd
 |   |       +- mult_macro      (Xilinx unimacro, uses one DSP)
 |   |       +- add_overflow (x 2)
 |   +- scheduler               (i_scheduler_res, selects the column whose result is accepted)
 +- pix                         src/pix.vhd (pixel counters)
 +- disp_mem                    src/disp_mem.vhd (display memory)
 +- disp                        src/disp.vhd (VGA output)
```
The number of columns (and therefore iterators and DSPs) is set by the generic
`G_NUM_ITERATORS`, which the top level sets to 240.

The files `src/priority.vhd` and `src/priority_pipeline.vhd` are not part of
this hierarchy. The module `priority_pipeline` instantiates two `priority`
modules, but is itself only instantiated by its own testbench
([`sim/priority_pipeline_tb.vhd`](sim/priority_pipeline_tb.vhd)). The scheduler
does not use them.

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
multiplier ([`sim/mult_tb.vhd`](sim/mult_tb.vhd)).

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

The testbench for the iterator is only investigative, and only tests a single starting
value: -1 + 0.5\*i.

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
calculation. Both start\_i and done\_o are pulsed high for a single clock
cycle.

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

TODO: The DSP contains an adder (as well as the multiplier). Perhaps it is
possible to use this built-in adder and thereby save logic resources. This may
perhaps improve the timing slightly. However, overflow detection needs to be
rewritten then.

## Columns
The final picture is sliced into vertical columns, and each column is calculated
in its entirety, see [`src/column.vhd`](src/column.vhd).

The inputs to this block are:
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
calculation of an entire column, and the output job\_busy\_o remains high
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
The signals start\_i and done\_o are pulsed high for one clock cycle to
initiate the calculation and to indicate completion, respectively. Three
additional output signals go to the display memory:
```
wr_addr_o : out std_logic_vector(18 downto 0);
wr_data_o : out std_logic_vector( 8 downto 0);
wr_en_o   : out std_logic;
```

This module instantiates a configurable number of 'column' modules (ideally 240
instances, one for each DSP). It keeps track of which columns are currently
calculating, and whenever a column is idle, a new job is sent to this column.

A separate scheduler module is used to send jobs to the different column
modules. Currently, the scheduler operates in a round-robin fashion. This
potentially may give a delay up to 240 clock cycles before an idle column is
given a job. With 640 jobs, the maximum delay is about 1 ms, assuming the
columns operate at 150 MHz. This delay is negligible.

## Timing
Counters measure the total time it takes to generate the picture as well as the
total amount of time the iterators are waiting to write to display memory.

The total time taken is 472\*2^11 clock cycles, which at a frequency of 150 MHz
becomes 6.4 milliseconds.

The average waiting time for each iterator is 28642/240 \* 2^11 clock cycles,
which is 1.6 milliseconds. So a quarter of the time is spent waiting. However,
at this processing speed it really doesn't matter.

Another way of looking at this is that each iterator is using 472\*2^11 clock
cycles, so a total of 232 million clock cycles. The average amount per pixel is
then obtained by dividing by 640 and by 480, which gives 755 clock cycles, or
in other words 252 iterations per pixel.

## Resources and timing closure
The numbers below come from a successful run of `make vivado` (Vivado 2025.1,
part xc7a100tcsg324-1, i.e. speed grade -1), which meets timing with a 150 MHz
main clock.

| Resource         | Used     | Available | Used (%)
| ---------------- | -------- | --------- | --------
| DSP48E1          | 240      | 240       | 100
| Block RAM        | 128 RAMB36 + 1 RAMB18 | 135 RAMB36 | about 95
| LUTs             | about 50,600 | 63,400 | about 80
| Registers        | about 52,600 | 126,800 | about 41
| Clock buffers    | 4 BUFG, 1 MMCM | |

The resource numbers are the cell counts after synthesis, taken from
`vivado.log`, and the available numbers are the totals for the XC7A100T. The
design uses memory with 2^19 entries of 9 bit, i.e. 128 blocks of 36 kbit
BRAM, as expected.

The timing after routing and post-route physical optimization is:

| Check | Slack
| ----- | -----
| Setup (WNS) | +0.047 ns (TNS 0)
| Hold (WHS)  | +0.018 ns (THS 0)

The timing is met for all clocks. The 150 MHz main clock (period 6.67 ns) is
generated from the 100 MHz input clock by the MMCM (multiplied by 10.5 and
divided by 7), and the only constraint in `mandelbrot.xdc` is the 100 MHz input
clock. The MMCM also generates the 25 MHz VGA clock and a 50 MHz clock.

The slack is small, so the design is close to the limit of what this device and
this flow can achieve. The critical paths are in the dispatcher: the selection
of the column in the schedulers (`job_idx_valid` and the `job_busy_o` signals
from the columns), and the registers for the write address and data going to
the display memory (`wr_addr_r` and `wr_data_r`). The initial result of placing
and routing does not meet timing (WNS about -0.2 ns), and it is the post-route
physical optimization that closes it, so the directives used in
`mandelbrot.tcl` matter:
* `synth_design` with `-directive AreaOptimized_medium`
* `opt_design` with `-directive ExploreWithRemap`
* `phys_opt_design` with `-directive AlternateFlowWithRetiming`, both after
  placement and after routing

A change to the design may therefore require different directives. Another
possible improvement is to pipeline the selection of the column in the
scheduler, e.g. by dividing the columns into 16 groups of 16. This has not been
tried.

The complete run of `make vivado` takes about 10 minutes (synthesis about 2
minutes, routing about 3 minutes), on a machine with 8 threads.

All 240 DSPs running at 150 MHz gives a peak of 36 billion multiplications per
second. The iterator uses its multiplier in two out of three clock cycles, so
the actual rate is about 24 billion multiplications per second.
