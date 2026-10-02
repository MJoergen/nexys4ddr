# The algorithm and its implementation
This describes in some detail how the Mandelbrot design works, and the main
parts it is built from. See [README.md](README.md) for an overview, a list of
files, and how to build and run the design.

The design is implemented on the Nexys 4 DDR board, which uses a Xilinx FPGA
XC7A100T. This FPGA has a total of 240 DSPs, which are all used for the actual
calculations. Additionally, the FPGA contains 135 BRAMs (of 36 kbit each),
which are used for storing the results of the calculation, i.e. the actual
picture to be displayed.

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

The testbench is not self-verifying, only investigative. This means one has to
manually examine the waveforms in order to determine whether the multiplier
works as expected. This is really just laziness and can easily be fixed.

The testbench currently performs the following multiplications:
```
-0.000015 * -0.000015 =  0.0000000002
-0.000015 *  0.000015 = -0.0000000002
 0.000015 *  0.000015 =  0.0000000002
 1.999985 *  1.999985 =  3.99994
-0.000015 *  1.999985 = -0.00003
```

The multiplier can be instantiated with a configurable number of clock cycles
of delay. A single clock cycle of delay is used for the time being. This may
have to be incremented if the clock frequency is increased.

## Iterator
This component ([`src/iterator.vhd`](src/iterator.vhd)) performs the main
calculation. It takes as input the complex number c (or rather the real and
imaginary values cx and cy). It then iterates the Mandelbrot function a number
of times and stops when either the maximum iteration count is reached, or an
overflow occurs.

The testbench is again only investigative, and only tests a single starting
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

## Resources
The XC7A100T contains the following number of resources:

* 240 DSPs
* 4.8 Mbit Block RAM
* 1.1 Mbit Distributed RAM

The design uses memory with 2^19 entries of 9 bit, i.e. 128 blocks of 36 kbit
BRAM. The FPGA contains 135 of such BRAMs, so that should be possible.

Timing estimates: Using all 240 DSPs allows a maximum frequency of 57 MHz, i.e.
13.7 GFLOPS. If we reduce the number to only 64 DSPs then the frequency
increases to 141 MHz, i.e. 9.1 GFLOPS.

With all 240 DSPs the bottleneck is the selection of iterator index in
`src/dispatcher.vhd`. This can perhaps be mitigated by a pipeline structure, by
dividing into 16 groups of 16 iterators.

With only 64 DSPs (and the higher frequency) the bottleneck is the addition
performed after the multiplication in `src/iterator.vhd`. This can probably be
mitigated by integrating the addition into the DSP itself.
