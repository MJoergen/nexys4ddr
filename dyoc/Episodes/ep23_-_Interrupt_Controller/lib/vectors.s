.setcpu		"6502"

.import init                  ; Declared in lib/crt0.s
.import nmi_int, irq_int      ; Declared in lib/irq.s

.segment "VECTORS"            ; The linker script ld.cfg ensures
                              ; that this segment is placed at
                              ; the correct memory address

.addr nmi_int    ; NMI vector
.addr init       ; Reset vector
.addr irq_int    ; IRQ/BRK vector

