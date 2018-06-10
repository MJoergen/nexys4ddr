.setcpu  "6502"
.import   axulong    ; Convert uint16_t to uint32_t
.export  __systime
.export  _timer_100
.export  _timer

.segment "BSS"

_timer_100:
	.res	1,$00
_timer:
	.res	2,$00

; ---------------------------------------------------------------
; unsigned long __near__ _systime (void)
; ---------------------------------------------------------------

.segment "CODE"

.proc	__systime: near

	PHP               ; It is necessary to disable interrupts.
                     ; while reading the timer value. Otherwise,
                     ; if an interrupt occurs before the LDX,
                     ; the value may change.
   SEI
	LDA     _timer
	LDX     _timer+1
	PLP               ; Now it's safe to reenable interrupts.
	JMP     axulong   ; Convert to uint32_t

.endproc

