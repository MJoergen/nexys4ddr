.import init
.import nmi_int, irq_int

.segment "VECTORS"

.addr nmi_int    ; NMI vector
.addr init       ; Reset vector
.addr irq_int    ; IRQ/BRK vector

