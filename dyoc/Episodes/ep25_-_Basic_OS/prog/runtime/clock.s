.setcpu  "6502"
.import  axulong
.export  _clock
.import  _timer         ; 16-bit counter

; ---------------------------------------------------------------
; unsigned long __near__ clock (void)
; ---------------------------------------------------------------

.segment "CODE"

.proc	_clock: near

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

