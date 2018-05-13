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

end:
   LDA sum
   JMP end

