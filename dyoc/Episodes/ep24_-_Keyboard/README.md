# Design Your Own Computer
# Episode 24 : "Keyboard"
 
Welcome to "Design Your Own Computer".  In this episode we'll add support for
reading keystrokes from the keyboard.

Reading from the keyboard requires implementing a simple PS/2 reader in the FPGA.
When the keyboard detects a state change (e.g. pressing or releasing a key) it
sends one or more bytes to the FPGA over the PS/2 interface. The FPGA needs
to buffer these bytes internally, until the CPU is ready to read them.

