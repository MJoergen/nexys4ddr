.import _stop
.export _irq_int, _nmi_int

.segment "CODE"

_nmi_int:
   RTI

_irq_int:
   RTI

