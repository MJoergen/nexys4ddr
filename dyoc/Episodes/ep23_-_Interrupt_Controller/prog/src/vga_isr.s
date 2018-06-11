.setcpu		"6502"
.export		_vga_isr    ; Referenced in src/main.c

; The interrupt routine must be written entirely in assembler, because the C code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main program.

; The 'A' and 'Y' registers must NOT be changed in this routine.

; These addresses must match those in include/memorymap.h
VGA_PALETTE   = $7FC0   
VGA_PIX_Y_INT = $7FD0

PIXELS_Y      = 480     ; Number of lines in visible screen

.segment "ZEROPAGE"

tmp:
   .byte 0

.segment	"CODE"

_vga_isr:

   STA tmp              ; Save A register
   LDA VGA_PIX_Y_INT    ; Load current line number
   LDX VGA_PIX_Y_INT+1

   STA VGA_PALETTE      ; Update background colour

   CLC                  ; Increment line number
   ADC #$01
   BNE noc
   INX
noc:

   CPX #>PIXELS_Y        ; Have we reached bottom of visible screen?
   BNE nowrap
   CMP #<PIXELS_Y
   BNE nowrap
   LDA #$00
   LDX #$00
nowrap:

   STA VGA_PIX_Y_INT    ; Store new line number
   STX VGA_PIX_Y_INT+1

   LDA tmp              ; Restore 'A' register
   RTS

