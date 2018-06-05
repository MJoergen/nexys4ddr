.import _init
.import _nmi_int, _irq_int

.segment "VECTORS"

.addr _nmi_int    ; NMI vector
.addr _init       ; Reset vector
.addr _irq_int    ; IRQ/BRK vector

