# 6502 implementation notes

## Internal registers
* A (8-bit) accumulator
* X (8-bit) index
* Y (8-bit) index
* SP (8-bit) stack pointer (upper high byte is always 0x01)
* PC (16-bit) program counter

## Opcode format
Most instructions are of the form AAABBBCC.
* AAA (bits 7-5) : Opcode
* BBB (bits 4-2) : Addressing mode
* CC (bits 1-0) : Opcode

## Addressing modes
* 000: (zero page, X)
* 001: zero page
* 010: #immediate       Take value directly from the incoming data bus.
* 011: absolute         Take value directly from the incoming data bus.
* 100: (zero page), Y
* 101: zero page, X
* 110: absolute, Y
* 111: absolute, X

## ALU operations (13 in total so far)
* Arithmetic shift left 1 bit (ASL)
* Logical shift right 1 bit (LSR)
* Rotate left 1 bit (ROL)
* Rotate right 1 bit (ROR)
* AND
* OR
* XOR
* Add with carry (ADC)
* Subtract with borrow (SBC)
* Increment with 1
* Decrement with 1
* Compare (same as SBC?)
* Test (same as AND?)

## Possible inputs to the ALU
* First  : A register
* Second : Result of addressing mode (only used for some operations)

## Possible outputs from the ALU
* A register

## TBD
* The TXA copies the X register to the A register. Should this go through the
  ALU?
* The LDX register copies the data bus to the X register. Should this go
  through the ALU?

# Example instructions (with possible control signals)

The list below is inspired by this page:
[https://en.wikibooks.org/wiki/6502_Assembly](https://en.wikibooks.org/wiki/6502_Assembly)

I'm looking at the following list of control signals
* ALU_M1 : This is a mux that controls the input to the first port of the ALU
* ALU_M2 : This is a mux that controls the input to the second port of the ALU
* A_M    ; This is a mux that controls the input to the A register
* WA     : This is a write signal to the A register
* X_M    ; This is a mux that controls the input to the X register
* WX     : This is a write signal to the X register
* Y_M    ; This is a mux that controls the input to the Y register
* WY     : This is a write signal to the Y register
* PC_M   ; This is a mux that controls the input to the PC register
* WPC    : This is a write signal to the PC register
* DATA_M : This is a mux that controls what is sent to the data output.
* WDATA  : This is a write signal to the memory.

## ASL
This should copy the A register into the ALU1, and copy the result back into
the A register.
* ALU_M1 : Read from A register
* A_M    : Read from ALU output
* WA     : 1

## TXA
This should copy the X register into the A register.
* A_M    : Read from the X register
* WA     : 1

## LDA #$22
This should copy the data input (second byte of instruction) into the A
register.
* A_M    : Read from the data input
* WA     : 1

## LDX $D010
This should copy the data input (after reading from memory) into the X
register
* X_M    : Read from the data input
* WX     : 1

## LDY @02
This should copy the data input (after reading from memory) into the Y
register
* Y_M    : Read from the data input
* WY     : 1

## BPL $2D
This should copy the PC to the first input of the ALU, and the data
input (second byte of instruction) to the second input of the ALU. The output
should be written into the PC register.
* ALU_M1 : PC
* ALU_M2 : data input
* PC_M   : ALU
* WPC    : 1

## ADC $C001,X
This should add the value $C001 (second and third bytes of the instruction)
with the value in X. The contents of this memory location should be added to
the A register

So first it does:
* ALU_M1 : X
* ALU_M2 : Stored value of second and third byte
* WADDR  : 1

Second it does:
* ALU_M1 : A
* ALU_M2 : data input
* A_M    : ALU
: WA     : 1

## INC $F001,Y
This should add the value $F001 (second and third bytes of the instruction)
with the value in Y. The contents of this memory location are then read, and 
finally written to.

So first it does:
* ALU_M1 : Y
* ALU_M2 : Stored value of second and third byte
* WADDR  : 1

Second it does:
* ALU_M1 : data input
* WTEMP  : 1

Third it does
* DATA_M : From WTEMP
* WDATA  : 1

## LDA $01,X
This should add the value $0001 (second byte of the instruction)
with the value ib X. The contents of this memory location are the read into
the A register.

So first it does:
* ALU_M1 : X
* ALU_M2 : Input data (second byte of instruction)
* WADDR  : 1

Second it does:
* A_M    : ALU
: WA     : 1

## STA ($15,X)
This should add the value $0015 (second byte of the instruction)
with the value in X. The two-byte contents of this memory location
are then stored in a temporary address register, and the value of
A is written to this address

So first it does:
* ALU_M1 : X
* ALU_M2 : Input data (second byte of instruction)
* ALU_OPC : Add with carry clear
* WADDR  : 1

Second it does:
* TEMPL_M  : Input data
* WTEMPL   : 1
* ALU_M1   : X
* ALU_M2   : Input data (second byte of instruction)
* ALU_OPC  : Add with carry set
* WADDR    : 1

Third it does:
* TEMPH_M  : Input data
* WTEMPH   : 1

Fourh it does:
* WADDR   : 1
* DATA_M  : A register
* WDATA   : 1

## LSR ($2A),Y
This reads the two-byte contents of memory address $002A. This is added to 
the Y register and then stored in a temporay address register. The value
at this adress is read, put in the ALU, and then written back.

TBD...


