.setcpu "6502"

.export _clrscr

.include "zeropage.inc"       ; ptr1

; These constants must match those in include/memorymap.h
MEM_CHAR  = $8000
MEM_COL   = $A000
SIZE_CHAR = $2000
SIZE_COL  = $2000

.proc	_clrscr: near

.segment	"CODE"

_clrscr:
   LDY #<MEM_CHAR             ; Address of character memory
   LDX #>MEM_CHAR
   STY ptr1                   ; Store address in zeropage pointer
   STX ptr1+1
   LDA #' '                   ; ASCII code for ' '
   LDX #>MEM_CHAR+>SIZE_CHAR  ; High byte of end pointer
   LDY #$00                   ; Loop counter
loop:                         ; Fill 256 bytes with ' '
   STA (ptr1),Y
   INY
   BNE loop
   INC ptr1+1                 ; Increment high byte
   CPX ptr1+1                 ; Have we reached the end?
   BNE loop                   ; If not, go back and continue.

   RTS

.endproc

