.setcpu "6502"

.export nmi_int, irq_int   ; Used by lib/vectors.s
.import timer_isr          ; Declared in lib/vga_isr.s
.import vga_isr            ; Declared in lib/vga_isr.s

; These must be the same addresses defined in prog/memorymap.h
IRQ_STATUS = $7FFF
IRQ_MASK   = $7FDF

.segment	"CODE"

nmi_int:
   RTI                     ; NMI is not implemented. Just return.

irq_int:
   PHA
   TXA
   PHA
   TYA
   PHA

   LDA IRQ_STATUS          ; Reading the IRQ status clears it.
   AND IRQ_MASK            ; Mask off any disabled interrupts.
   LSR                     ; Shift bit 0 (TIMER) to carry (see prog/memorymap.h)
   BCC done_timer
   JSR timer_isr
done_timer:

   LSR                     ; Shift bit 1 (VGA) to carry (see prog/memorymap.h)
   BCC done_vga
   JSR vga_isr
done_vga:

   PLA
   TAY
   PLA
   TAX
   PLA
   RTI

