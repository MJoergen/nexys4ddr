.setcpu		"6502"
.export		vga_isr     ; Used in lib/irq.s

; The interrupt routine must be written entirely in assembler, because the C code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main program.


.segment	"CODE"

vga_isr:                ; Not implemented yet.

   RTS

