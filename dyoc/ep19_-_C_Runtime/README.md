# Design Your Own Computer
# Episode 19 : "C Runtime"

Welcome to "Design Your Own Computer".  In this episode we will modify
the toolchain to support the C runtime, thus allowing us to make C programs
run on the CPU.

## The linker script ld.cfg
The implementation is taken from <https://cc65.github.io/doc/customizing.html>
and modified slightly.  Refer to the documentation at
<http://cc65.github.io/doc/ld65.html> for full details.
