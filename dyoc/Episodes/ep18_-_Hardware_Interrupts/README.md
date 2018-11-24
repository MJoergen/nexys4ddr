# Design Your Own Computer
# Episode 18 : "Hardware Interrupts"

Welcome to "Design Your Own Computer".  In this episode we will (almost) finish the CPU
by adding support for hardware interrupts, i.e IRQ, and NMI. Support for Reset
will be postponed to episode 19.

## Emulating IRQ and NMI
IRQ and NMI are, respectively, maskable and nonmaskable interrupts, generated
by asserting the two new input pins, irq\_i and nmi\_i, in cpu/cpu.vhd lines
16-18.  I've added the rst\_i pin as well, but support for Reset will as
mentioned be deferred to the next episode.

So far in this project, we have no source for generating IRQ and NMI. Only in a
later episode will we add IRQ generation into the VGA module. So for test
purposes, I've temporarily added a CIC module (Chip Interrupt Controller) in
mem/cic.vhd, and corresponding changes in mem/mem.vhd. By writing to the
address 0xBFFF it is possible to generate interrupts: Bit 0 is mapped to the
IRQ pin, and bit 1 is mapped to the NMI pin.

## Handling IRQ and NMI
The handling of the IRQ and NMI interrupt signals is performed in the Control
Logic, i.e.  cpu/ctl.vhd. However, since the IRQ is maskable, the Interrupt bit
of the Status Register must be forwarded to the Control Logic. This is the
sri signal in lines 67 and 98 in main/cpu/cpu.vhd.

The main idea in interrupt handling is by overwriting the Instruction
Register with the value 00 for BRK during an interrupt. This is done in lines
2762-2765 in main/cpu/ctl.vhd.

Hardware interrupts are prioritized in the following order Reset > NMI > IRQ >
BRK. Furthermore, the NMI signal is edge sensitive, whereas the IRQ signal is
level sensitive. This is all taken care of in lines 2784-2813 of
main/cpu/ctl.vhd

Lines 2823-2825 are changed, because it is necessary to overwrite some of the
control signals during interrupt.
* Line 2825 makes sure that the Break bit is cleared
when writing the Status Register to the stack during an NMI or IRQ.
* Line 2824 ensures that the correct interrupt vector is used for fetching the
new Program Counter.
* Finally, line 2823 prevents incrementing the Program
Counter during an IRQ or NMI. This is necessary to ensure the correct return
address is written to the stack.

## Status Register
When writing the Status Register to memory, the Break bit is set if the write
is caused by a BRK or PHP instruction, and the Break bit is cleared if the
write is caused by an IRQ or NMI. For more details, see the description
in <https://wiki.nesdev.com/w/index.php/Status_flags> and
<https://wiki.nesdev.com/w/index.php/CPU_status_flag_behavior>.

## Supported make targets are:
* make sim : Simulate the computer so far. It uses the functional test
  in mem/6502\_interrupt\_test.s as stimulus.
* make fpga : Program the FPGA and run the computer on the hardware.

The test ends after around 1500 clock cycles with the value $00 in the
A-register and the value $4C in the Instruction Register (executing a JMP
instruction at $C300).  This corresponds to approx eight seconds
in the hardware, when running with switch 7 set to on.

