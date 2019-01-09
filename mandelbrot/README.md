# Mandelbrot
Here I'll describe in some detail the design of the Mandelbrot program and its
main parts.  The design is implemented on the Nexys 4 DDR board, which uses a
Xilinx FPGA XC7A100T. This FPGA has a total of 240 DSP, which will all be used
for the actual calculations.  Additionally, the FPGA contains 144 BRAMs (of 18
kbit each), which will be used for storing the results of the calculation, i.e.
the actual picture to be displayed.

## Fixed point arithmetic
Before we proceed, we need to discuss how to represent decimal numbers in the
FPGA. I've chosen to use "fixed point binary two's complement", because that is
the easiest. Specifically, 2.16 bit representation is used, i.e. two bits for
the integer portion, and 16 bits for the fraction part.

This means we can represent real numbers in the range -2 .. 2, with an accuracy
of 0.5^16, i.e. about 5 decimal places of accuracy. A real number x is
represented using the binary number of x\*2^16, if x is positive, and
(x+4)\*2^16 if x is negative.

The first bit acts as a sign bit. It is '1' if the number of negative, and it
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
In this project we're using the built-in DSP to provide an 18-bit signed
multiplier.  This generates a 36-bit result in 4.32 bit representation.  The
actual multiplier is defined in a special Xilinx unimacro, but I've written a
testbench specifically for the multiplier (sim/mult\_tb.vhd).

The testbench is not selv-verifying, only investigative. This means one has to
manually examine the waveforms in order to determine, whether the multiplier
works as expected.  This is really just lazyness on my part and can easily be
fixed.

Anyway, the testbench currently performs the following multiplications:
```
-0.000015 * -0.000015 =  0.0000000002
-0.000015 *  0.000015 = -0.0000000002
 0.000015 *  0.000015 =  0.0000000002
 1.999985 *  1.999985 =  3.99994
-0.000015 *  1.999985 = -0.00003
```

The multiplier can be instantiated with a configurable number of clock cycles
of delay. I've chosen just a single clock cycle of delay for the time being.
This may have to be incremented when we start building the entire system. It's
very hard to predict what clcok frequencies the final design will be able to
run at.


## Iterator
This component (see src/iterator.vhd) performs the main calculation. It takes
as input the complex number c (or rather the real and imaginary values cx and
cy).  It then iterates the Mandelbrot function a number of times and stops when
either the maximum iteration count is reached, or an overflow occurs.

The testbench is again only investigative, and only tests a single starting
value: -1 + 0.5\*i.

The iterator has been heavily optimized to use only a single multiplier, and to
pipeline the calculations. Furthermore, the calculations have been rewritten to
use only two (real) multiplications:
```
new_x = (x+y)*(x-y) + cx
new_y = 2*(x*y) + cy
```

Each iteration takes three clock cycles, and is controlled by a simple state
machine:
* In the first clock cycle (ADD\_ST), the multiplier is given the values of x
  and y, and simultaneously, the values x+y and x-y are calculated.
* In the second clock cycle (MULT\_ST), the multipluer is given the values of
  (x+y) and (x-y), and the output from x\*y is stored in registers.
* In the third clock cycle (UPDATE\_ST), the new values of x and y are
  calculated.  The above three steps are repeated until a maximum loop count or
  until an overflow happens.

The inputs to this block are: start\_i, cx\_i, and cy\_i. Outputs are done\_o
and cnt\_o.  The values of cx\_i and cy\_i must be held constant for the entire
calculation.  Both start\_i and done\_o are pulsed high for a single clock
cycle.

Example:
We start with the point -1+0.5i, i.e. cx = -1 and cy = 0.5
The expected sequence of points is then:
```
cnt |   x           |   y           
----+---------------+---------------
 0  |  0    (00000) |  0    (00000)
 1  | -1    (30000) |  0.5  (08000)
 2  | -0.25 (3C000) | -0.5  (38000)
 3  | -1.19 (2D000) |  0.75 (0C000)
 4  | -0.15 (3D900) | -1.28 (2B800)
```
The values in the parenthesis are the (2.16 fixed point) hexadecimal
representation of the real numbers.

TODO: The DSP contains an adder (as well as the multiplier).  Perhaps it is
possible to use this built-in adder and thereby save logic reources. This may
perhaps improve the timing slightly. However, overflow detection needs to be
rewritten then.

## Columns
The final picture is sliced into vertical colums, and each column is calculated
in its entirety, see the file src/column.vhd.

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
arbitrary long delay before the job dispatcher has time to acknowledge the
result.

## Dispatcher
This is essentially the top level entity controlling the calculation of the entire
picture.  This is perhaps the most complicated module.  Again the input signals are:
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
Again, the signals start\_i and done\_o are pulsed high for one second to
initiate the calculation and to indicate completion, respectively.
Three additional output signals go to the display memory:
```
wr_addr_o : out std_logic_vector(18 downto 0);
wr_data_o : out std_logic_vector( 8 downto 0);
wr_en_o   : out std_logic;
```

This module instantiates a configurable number of 'column' modules (ideally 240
instances, one for each DSP). It keeps track of which columns are currently
calculating, and whenever a column is idle, a new job is sent to this column.

A separate scheduler module is used to send jobs to the different column
modules.  Currently, the scheduler operates in a round-robin fashion. This
potentially may give a delay up to 240 clock cycles before an idle column is
given a job. With 640 jobs, the maximum delay is about 1 ms, assuming the
columns operate at 150 MHz. This delay is negligible.

