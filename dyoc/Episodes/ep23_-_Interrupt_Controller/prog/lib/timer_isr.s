.setcpu		"6502"
.export		timer_isr      ; Used in lib/irq.s
.import     _timer_100     ; Defined in lib/_systime.s
.import     _timer         ; Defined in lib/_systime.s

; The interrupt routine must be written entirely in assembler, because the C code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main program.

; The 'A' and 'Y' registers must NOT be changed in this routine.

.segment	"CODE"

; This interrupt service routine is called 100 times pr. second.

timer_isr:
   INC _timer_100

   LDX _timer_100
   CPX #100
   BCC nowrap

   LDX #$00
   STX _timer_100
   INC _timer
nowrap:

   RTS

