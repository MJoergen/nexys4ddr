# Offloader #

Welcome to this tutorial series where we will build a *CPU offloader* on an FPGA!

## Scope of project ##

So, a CPU offloader is essentially a compute engine. It functions somewhat like
an extra CPU core, but can perform dedicated operations much faster, by
utilizing the special features of the FPGA.

The CPU offloader will run on the Nexys4DDR FPGA board, and will communicate
with the main PC via the Ethernet port. The way this works is that the main PC
sends a UDP packet to the Nexys4DDR with a computation command, and some time
later the Nexys4DDR sends one or more UDP packets back to the main PC with the
result of the computation.

The reason for using Ethernet is that the data transfer rate of 100 Mbit/s is
pretty fast, compared to using the USB port. And the reason for using UDP
packets is that it is a compromise between what is easy to implement in the
FPGA and what is easy to implement on the host PC. I could alternatively have
used raw Ethernet packets, but that would probably require root access to the
network interface on the PC, On the other hand, using TCP would require a lot of
design work on the FPGA. Therefore, UDP was chosen as a compromise.  This
choice does however require building a network stack on the FPGA, in particular
responding to e.g. ARP packets. More on that later.

Apart from being able to offload the CPU of the main PC, this project will be
built step by step, documenting each step as we go along, and thereby serve
a dual function as a tutorial in VHDL programming on an FPGA, i.e. digital
systems design.

## Applications ## 
The design will be generic enough to accommodate many different applications.
One of the first applications I intend to write is hardware acceleration of
integer factorization. This is the problem of determining the integers p and q,
given the value of N=p\*q, where N is a very large integer, say approx. 50
digits.  On a regular CPU this is a very compute intensive calculation, see
e.g.  [here](https://en.wikipedia.org/wiki/Integer_factorization_records).
However, many of the calculations can be massively parallelized leading
(hopefully) to large performance gains.

Another possible application is to perform advanced search and evaluation
function of board games, e.g. chess.

## Overall FPGA design ##

The main idea as mentioned is to utilize the Ethernet port on the Nexys4DDR
board.  The actual computations will be performed directly in the FPGA, and I
have chosen to write the network stack (including the network protocols MAC,
ARP, IP, UDP, etc)  directly in VHDL. An alternative is to build a small SoC,
i.e. have a CPU running on the FPGA that runs the network stack.  However,
since computation speed is important (that is after-all why we are offloading in
the first place), it makes sense to reduce network latency.

To help debugging, we will make use of the VGA output of the Nexys4DDR.
This is not essential for the offloading functionality itself, but gives a
pretty cool view of what is going on inside the FPGA.

## Overview of series ##

In the first few episodes we'll be setting up the project, and making a small
design that can display a string of hexadecimal characters to the VGA output.
This is very much similar to the first few episodes from the
[DYOC](https://github.com/MJoergen/nexys4ddr/tree/master/dyoc) series, but
since we won't be writing a CPU, the design will be slightly different.

In the subsequent episodes, we'll build a network processor, allowing the FPGA to
receive and send UDP packets.

## List of episodes: ##
### VGA ###
1.  [**"Hello World"**](Episodes/ep01_-_Hello_World). Here we will generate a
    checkerboard pattern on the VGA output.
2.  [**"Hex Digits"**](Episodes/ep02_-_Hex_Digits). Here we will implement a
    complete font and display data in hexadecimal format.
### Ethernet ###
3.  [**"Ethernet"**](Episodes/ep03_-_Ethernet). Here we will connect the
    Ethernet port.
4.  [**"CRC"**](Episodes/ep04_-_CRC). Here we will validate Ethernet CRC and
    discard frames with CRC errors.
5.  [**"ARP"**](Episodes/ep05_-_ARP). Here we will respond to ARP requests.
6.  [**"ICMP"**](Episodes/ep06_-_ICMP). Here we will respond to ICMP requests.
7.  [**"UDP"**](Episodes/ep07_-_UDP). Here we will respond to UDP requests.
### Math ###
8.  [**"MATH"**](Episodes/ep08_-_Math). Here we start with the first simple
    matematical algorithms, here the integer square root.
9.  [**"CF"**](Episodes/ep09_-_CF). Here we will implement the Continued
    Fraction method to generate a large number of pairs (x, y) needed for the
    factorisation.
10. [**"Fact"**](Episodes/ep10_-_Fact). Here we will add factorisation of the
    intermediate results.

More to come soon...

## Prerequisites ##

### FPGA board ###

To get started you need an FPGA board. I'll be using 
[Nexys 4 DDR](https://reference.digilentinc.com/reference/programmable-logic/nexys-4-ddr/start)
(from Digilent), because it has an Ethernet port.

### FPGA toolchain (software) ###

The Nexys 4 DDR board uses a Xilinx FPGA, and the toolchain is called
[Vivado](https://www.xilinx.com/support/download.html).
Use the Webpack edition, because it is free to use.
I'm using version 2018.2, but anythig newer than that is fine too.

## Recommended additional information ##

I will in this series assume you are at least a little familiar with logic
gates and digital electronics.

I will also assume you are comfortable in at least one other programming
language, e.g. C, C++, Java, or similar.

## About me ##

I'm currently working as a professional FPGA developer, but have previously
been teaching the subjects mathematics, physics, and programming in High School.
Before that I've worked for twelve years as a software developer.

