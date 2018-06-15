.setcpu  "6502"
.export  screensize

.segment "CODE"

screensize:
   LDX #80
   LDY #60
   RTS

