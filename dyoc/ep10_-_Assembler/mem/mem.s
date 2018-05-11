	.fopt		   compiler,"cc65 v 2.16 - Git 1ea5889a"
	.setcpu		"6502"
	.smart		on
	.autoimport	on
	.case		   on
	.debuginfo	off
	.macpack	   longbranch

.segment	"CODE"


   LDA #$0A
   STA $03FF
   LDA #$00
   STA $03FE
   loop:
   LDA $03FE
   CLC
   ADC $03FF
   STA $03FE
   LDA $03FF
   SEC
   SBC #$01
   STA $03FF
   BNE loop
   LDA $03FE
   end:
   JMP end
