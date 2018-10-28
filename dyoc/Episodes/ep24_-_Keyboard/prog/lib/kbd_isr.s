.setcpu		"6502"
.export		kbd_isr              ; Used in lib/irq.s
.import     _kbd_buffer_count, _kbd_buffer, _kbd_buffer_size   ; Defined in lib/keyboard.c

; The interrupt routine must be written entirely in assembler, because the C
; code is not re-entrant.
; Therefore, one shouldn't call C functions from this routine.
; Furthermore, it should be short and fast, so as not to slow down the main
; program.

; The 'A' and 'Y' registers must NOT be changed in this routine.


; Address of memory mapped IO to read last keyboard event.
; Must match the corresponding address in prog/keyboard.h
KBD_DATA   = $7FE8

.segment	"CODE"

; The interrupt service routine
; It will append the current keyboard event to the end of the buffer
; and increment the size of the buffer.
; If however the buffer is full, the current keyboard event is discarded.

kbd_isr:
   LDX _kbd_buffer_count         ; Get buffer size
   CPX _kbd_buffer_size          ; Is buffer full ?
   BCS end                       ; If yes, jump
   PHA
   LDA KBD_DATA                  ; Get last keyboard event
   STA _kbd_buffer,X             ; Append to end of buffer
   INC _kbd_buffer_count         ; Increment buffer size
   PLA
end:
   RTS

