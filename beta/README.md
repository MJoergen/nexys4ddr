# Executive summary
I watched the lecture series for MIT 6.004 "Computation Structures", where they
build a 32-bit computer called "Beta".  My plan is to implement this computer
on a NEXYS4 DDR board from DigilentInc.

The NEXYS4 DDR board is built around a Xilinx Artix-7 FPGA, specifically a
XC7A100T with approx 100 K logic cells and 540 KB RAM.  The FPGA is
furthermore connected to a 128 MB DDR2 RAM.

# Overall plan
The intent is to get a design working on the board, using the VGA output for
debug purposes, e.g. showing the contents of all the registers.

I will start by implementing the unpipelined version. I need to come up with a
plan for thoroughly testing my implementation. I also need to figure out how to
write a compiler for the Beta CPU.

# References
* The NEXYS4 DDR boaard is documented [here](https://reference.digilentinc.com/reference/programmable-logic/nexys-4-ddr/start).
* The MIT lecture series is [here](https://www.youtube.com/watch?v=CvfifZsmpQ4&list=PLEyT25pFrWyP_xmCoUTHG74wllpGPX5BC).
* The description of the Beta [design](https://www.youtube.com/watch?v=FQs7LuHb0cA&list=PLEyT25pFrWyP_xmCoUTHG74wllpGPX5BC&index=14).
* Course [website](https://6004.mit.edu/).
* Lab [material](https://ocw.mit.edu/courses/electrical-engineering-and-computer-science/6-004-computation-structures-spring-2009/).

# Log
I will be keeping a log of my work, please see the file log.md

