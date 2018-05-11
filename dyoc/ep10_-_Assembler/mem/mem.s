	.setcpu		"6502"

.segment	"CODE"
   LDA #$0A
   STA tmp
   LDA #$00
   STA sum

loop:
   LDA sum
   CLC
   ADC tmp
   STA sum

   LDA tmp
   SEC
   SBC #$01
   STA tmp

   BNE loop

   LDA sum
end:
   JMP end

.ORG $03FE  ; Make sure the two variables are placed at the end of the memory.

sum: .byte $00
tmp: .byte $00
