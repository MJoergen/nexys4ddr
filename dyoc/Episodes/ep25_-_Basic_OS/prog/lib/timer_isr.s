.setcpu		"6502"
.export		timer_isr      ; Used in lib/irq.s
.import     _timer         ; 16-bit counter

; The interrupt routine must be written entirely in assembler, because the C
; code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main
; program.

; The 'A' and 'Y' registers must NOT be changed in this routine.

.segment	"CODE"

timer_isr:
   INC _timer
   BNE nowrap
   INC _timer+1
nowrap:

   RTS

