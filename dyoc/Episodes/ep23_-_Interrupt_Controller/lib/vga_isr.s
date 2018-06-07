.setcpu		"6502"
.export		vga_isr     ; Used in lib/irq.s

; The interrupt routine must be written entirely in assembler, because the C code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main program.

; These addresses must match those in prog/memorymap.h
VGA_PALETTE   = $7FC0   
VGA_PIX_Y_INT = $7FD0

PIXELS_Y      = 480     ; Number of lines in visible screen

.segment	"CODE"

vga_isr:

   LDA VGA_PIX_Y_INT    ; Load current line number
   LDX VGA_PIX_Y_INT+1

   CLC                  ; Increment line number
   ADC #$01
   BNE noc
   INX
noc:

   CPX #>PIXELS_Y        ; Have we reached bottom of screen?
   BNE nowrap
   CMP #<PIXELS_Y
   BNE nowrap
   LDA #$00
   LDX #$00
nowrap:

   STA VGA_PIX_Y_INT    ; Store new line number
   STX VGA_PIX_Y_INT+1

   STA VGA_PALETTE      ; Update background colour

   RTS

