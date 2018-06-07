.setcpu "6502"

.export nmi_int, irq_int
.import kbd_isr, vga_isr

IRQ_STATUS = $7FFF ; see prog/memorymap.h

.segment	"CODE"

nmi_int:
   RTI

irq_int:
   PHA
   TXA
   PHA
   TYA
   PHA

   LDA IRQ_STATUS    ; Reading the IRQ status clears it.
   LSR               ; Shift bit 0 (VGA) to carry (see prog/memorymap.h)
   BCC done_vga
   JSR vga_isr
done_vga:

   LSR               ; Shift bit 1 (KBD) to carry (see prog/memorymap.h)
   BCC done_kbd
   JSR kbd_isr
done_kbd:

   PLA
   TAY
   PLA
   TAX
   PLA
   RTI

