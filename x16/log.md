# Progress Log

This file contains a brief description of my process with implementing the X16
on the Nexys4DDR board.

## 2019-10-26
Initial checkin, where the VGA port displays a simple checkerboard pattern in
640x480 resolution.  I'm planning on running the entire design using two
clocks: The VERA will run at the VGA clock of 25 MHz, and the rest of the
design will run at the CPU clock of 8 MHz.

Next step: In order to get the VERA to display more than a checkerboard, I need
to dive into the VERA documentation. My intention is to get the default
character mode to work. The challenging part is actually how to test this
incrementally, i.e without having to wait until everything is implemented. I
will probably just hard code some characters and fonts to begin with, but then
quickly move on to implement the interface to the 65C02, and then hardcode a
process that simulates the CPU writes to the VERA.

I will wait with implementing the CPU, as I already have a working 6502 from
the dyoc project, where I just need to modify it for the 65C02.

## 2019-10-27
I've generated a list of all the writes performed by the KERNAL/BASIC during
startup, and this gives information on how to initialize the VERA. I will need
to emulate this when testing (before I implement the CPU). See the
[README](fpga/vera/README.md) in the vera subdirectory.

I've started implementing mode 0 (the default text mode). However, I've
immediately run into a problem. For each pixel being displayed, the VERA must
perform two reads from the Video RAM:
1. Reading from the MAP area to get the character value at the corresponding pixel.
2. Reading from the TILE area to get the tile data for this character.

Initially I had planned to place the MAP and TILE areas in two separate Block
RAMs, so that the reads could be performed simultaneously. However, with the
very flexible interface of the VERA this is not possible. So I need to rethink
this.  Furthermore, when implementing the sprite functionality I will need to
perform additional reads from the Video RAM.

## 2019-10-28
I realized that reading from Video RAM only needs to take place for every tile,
and not for every pixel. And since each tile is (at least) 8 pixels wide, there
is adequate time for reading.

The module needs to perform three reads from Video RAM for each eight
horizontal pixels: Two bytes from the MAP area, and one byte from the TILE
area.

So far, I'm ignoring all writes to the configuration registers, and only
focusing on getting the reads from Video RAM working properly. I've copied
(most of) the startup writes performed by the KERNAL/BASIC into a small module
that simulates the CPU. This should generate the same startup screen as the
X16, albeit with a black background.

To help debug the VERA implementation, I've added a test bench for simulating
the VERA. This immediately helped me find two bugs in mode0.vhd. One bug was
that the staged pixel counters were only updated once every tile, but should be
updated on every pixel. The other was insufficient delay when reading from
Video RAM.

## 2019-10-29
Testing mode 0 on hardware revealed a simple error of each tile being mirrored,
which was easy to fix.

I've faked the background colour by initializing the entire VRAM with blue
colour ('6' for background and foreground). This is just a temporary hack until
I get the CPU and KERNAL running.

I've added the translation between the internal and external memory map. The
writes to the VERA block have been changed to reflect the external addressing,
and I've added the writes to the VERA configuration registers. A few of these
registers are implemented, the rest are ignored.

I've renamed the file mode0.vhd to layer.vhd to better reflect its purpose,
and I've added a block diagram of my current limited implementation of the VERA.

The next step is to get the 65C02 CPU up and running.  In another project
[https://github.com/MJoergen/cpu65c02](https://github.com/MJoergen/cpu65c02)
I've ported a complete functional test suite for the 65C02. This I will use to
test my implementation of the 65C02 CPU. I already have a working 6502
implementation in my [Design Your Own
Computer](https://github.com/MJoergen/nexys4ddr/tree/master/dyoc) project, so
that should be a relatively easy task.

I still need to be very careful about the interface between the CPU and the
VERA, because they will be running two different clock frequencies.  In
particular, since reading from the VERA potentially updates the state in the
VERA (addresses auto-increment) this makes the task very delicate.

## 2019-10-31
Getting the CPU read access turned out to be a lot more work than anticipated.
Originally, I had planned to run the VERA and the CPU on separate clock
domains, and have a clock domain crossing (CDC) circuit in the top level
module.  However, this would cause large delays (latency) when the CPU wants to
read from the VERA.

Instead, I now use the fact that the Block RAMs in the FPGA are true dual port,
so one port can run on the CPU clock and the other on the VGA clock.  The VERA
module must therefore have both clocks, which changes the design considerably.

From a hardware perspective this also makes much more sense. A physical VERA
chip would have pins connecting to the CPU, including a corresponding CPU clock
signal, and would also have another VGA clock signal to drive the VGA output
pins.

I still don't have the CPU implemented, so I'm using a mock cpu\_dummy module,
and I've moved this into the top level, i.e. outside the VERA module.

The next step is now to get the CPU running.

