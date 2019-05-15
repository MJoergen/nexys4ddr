# CPU offloader
# Episode 3 : "Ethernet"

Welcome to this third episode of "CPU offloader", where we enable the
Ethernet port.

This episode is very simnilar to the corresponding episode [Episode 26 -
Ethernet
Phy](https://github.com/MJoergen/nexys4ddr/tree/master/dyoc/Episodes/ep26_-_Ethernet_PHY)
in the DYOC tutorial.

In the followuing I'll summarize the main development in this episode:

First of all, in the files top.vhd (lines 15-25) and top.xdc (lines 22-33)
we've added the pins connecting to the Ethernet Phy, In top.vhd the Ethernet
interface is instantiated in lines 77-95.

## Clock domains

Now, the Ethernet module needs a 50 MHz clock, so we generate this in line 60
of top.vhd using the same clock divider method as for the VGA clock. The clock
must also be declared in line 38 of top.xdc.

Next, the Ethernet module provides a debug signal (currently just counting the
number of correctly received frames), but this signal (line 42 in top.vhd) is
synchronous to the Ethernet clock.  However, the VGA module requires a signal
synchronuous to the VGA clcok, and therefore we need a Clock Domain Crossing,
This is handled in lines 98-111 in top.vhd, where the cdc module is instantiated.

This Clock Domain Crossing module (cdc.vhd) is a wrapper for a Xilinx
Parameterized Macro (XPM), and these have to be explicitly enabled. This is
done in line 14 of the Makefile.

## Ethernet

The files for the Ethernet module are placed in the separate directory eth, and
the top level block for the Ethernet module is eth/eth.vhd.

