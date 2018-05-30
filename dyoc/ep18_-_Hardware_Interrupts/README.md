# Design Your Own Computer
# Episode 18 : "Hardware Interrupts"

Welcome to "Design Your Own Computer".  In this episode we will finish the CPU
by adding support for hardware interrupts, i.e Reset, IRQ, and NMI.

## Status Register
WHen writing the Status Register to memory, the Break bit is set if the write
is caused by a BRK or PHP instruction, and the Break bit is cleared if the
write is caused by an IRQ or NMI. For more details, see the description
in <https://wiki.nesdev.com/w/index.php/Status_flags> and <https://wiki.nesdev.com/w/index.php/CPU_status_flag_behavior>.
