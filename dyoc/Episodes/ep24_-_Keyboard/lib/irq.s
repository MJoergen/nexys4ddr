.setcpu "6502"

.export nmi_int, irq_int   ; Used by lib/vectors.s
.import kbd_isr, vga_isr   ; Declared in lib/kbd_isr.s and lib/vga_isr.s

IRQ_STATUS = $7FFF         ; This must be the same address defined in prog/memorymap.h

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
   LSR                     ; Shift bit 0 (VGA) to carry (see prog/memorymap.h)
   BCC done_vga
   JSR vga_isr
done_vga:

   LSR                     ; Shift bit 1 (KBD) to carry (see prog/memorymap.h)
   BCC done_kbd
   JSR kbd_isr
done_kbd:

   PLA
   TAY
   PLA
   TAX
   PLA
   RTI

