# Design Your Own Computer
# Episode 5 : "Datapath"

Welcome to the fifth episode of "Design Your Own Computer". In this
episode we will make a rudimentary skeleton of the CPU. The
CPU will consist of two parts:
* The Data Path
* The Control Logic

Instructions implemented in total : 1/151.

## External Interfaces of the CPU
The CPU will interface directly to the memory, so the ports of the 
CPU will be a direct mirror image of the memory ports.
The CPU will have an additional debug output, providing information
on all the internal state inside the CPU. This is the information
that will be presented on the VGA screen, so we can follow what
the CPU is doing.

## What is inside a CPU?
Most CPU's are actually quite similar in their construction. They
contain the following elements:
* A Program Counter
* Internal Registers
* Instruction Register
* Instruction Cycle Counter

The first two elements (Program Counter and Internal Registers) is
collectively called the Data Path, while the Instruction Register and 
Cycle Counter make up the Control Logic.

## Instructions in the 6502 CPU
Each instruction consists of between 1 and 3 bytes. The first byte
is the OpCode and can take any of the 256 different values of a byte.
However, many of these values are not allowed and correspond to
Undefined instructions. This leaves 151 different possible instructions.
The 0-2 bytes following the OpCode consists of additional parameters.
Detailed information on the 6502 instruction set can be found
in this link: <http://nesdev.com/6502.txt>.

The plan is to implement these instructions one by one, and in the process
gradually expand the implementation of the CPU. The first instruction we'll
implement is "LDA #", called "Load A-register immediate".  This is a two-byte
instruction, the first byte contains the value 0xA9, and the second byte
contains a value that will be copied into the 'A' register.

## Data Path
In order to read the instructions from memory, the CPU must present the Program
Counter to the address pins. This happens in line 58 in cpu/datapath.vhd.
Additionally, at each clock cycle the Program Counter should be incremented.
This happens in lines 31-39.

The 'A' register should read its value from the data input, but not in every
clock cycle. There shall therefore be a control signal "a\_sel" that controls
whether the 'A' register should update its value. This is handled in lines
41-51.

## Control Logic
The most important register in the control logic is the Instruction Register,
which will be updated at the beginning of every new instruction. We therefore
additionally need a Cycle Counter that contains which cycle within an instruction
we are currently executing.

The Instruction Register is updated in lines 55-65 in cpu/ctl.vhd, but only on
the very first clock cycle of the current instruction, i.e. when cnt = 0.

The Cycle Counter is updated in every clock cycle, and is reset at the end
of the instruction. This happens in lines 41-53.

Finally the control signals themselves are assigned combinatorially in lines
67-72.

## VGA
The file vga/digits.vhd has been expanded slightly in order to allow displaying
text on the screen.  The actual text displayed in front of each row is written
in lines 63-64, and the position is defined in lines 60-61.  The signal
txt\_offset has been added to contain the index into the text string.  The text
character is determined in line 141 in a rather cumbersome way. This is a
consequence of the strict type checking in the VHDL language.  The choice of
which character to display in performed in lines 143-147, where three
possibilities are chosen between.

