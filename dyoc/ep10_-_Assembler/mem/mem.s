	.setcpu		"6502"

.segment	"CODE"

; Test S and Z when loading $00.
; Conditional branch forward
   LDA #$00
   BNE error1     ; Should not jump
   BMI error1     ; Should not jump
   BEQ noError1   ; Should jump
error1:
   LDA #$01
   JMP error1
noError1:
   BPL noError1a  ; Should jump
   JMP error1
noError1a:

; Test S and Z when loading $01.
; Conditional branch forward
   LDA #$FF
   BEQ error2     ; Should not jump
   BPL error2     ; Should not jump
   BNE noError2   ; Should jump
error2:
   LDA #$02
   JMP error2
noError2:
   BMI noError2a  ; Should jump
   JMP error2
noError2a:

; Test C.
; Conditional branch forward
   CLC
   BCS error3     ; Should not jump
   BCC noError3   ; Should jump
error3:
   LDA #$03
   JMP error3
noError3:
   SEC
   BCC error3     ; Should not jump
   BCS noError4   ; Should jump
   JMP error3

; Next we test conditional branching backward
noError4c:
   LDA #$FF
   BNE noError4e  ; Should jump
   JMP error4d
noError4b:
   LDA #$00
   BEQ noError4c  ; Should jump
   JMP error4d
noError4a:
   SEC
   LDA #$00       ; Verify carry is not altered
   BCS noError4b  ; Should jump
   JMP error4d
noError4:
   CLC
   LDA #$00       ; Verify carry is not altered
   BCC noError4a  ; Should jump
   JMP error4d
error4d:
   LDA #$04
   JMP error4d
noError4e:

; Now we test compare
   SEC            ; Preset. Should be cleared in compare.
   LDA #$55
   CMP #$AA
   BCS error5a    ; Should not jump
   BCC noError5a  ; Should jump
error5a:
   LDA #$05
   JMP error5a
noError5a:
   BEQ error5a    ; Should not jump
   BPL error5a    ; Should not jump

   CLC            ; Preclear. Should be set in compare.
   CMP #$55       ; Verify value in A register is unchanged.
   BCC error5c    ; Should not jump
   BCS noError5c  ; Should jump
error5c:
   LDA #$05
   JMP error5c
noError5c:
   BNE error5c    ; Should not jump
   BMI error5c    ; Should not jump

   CLC            ; Preclear. Should be set in compare.
   CMP #$33
   BCC error5b    ; Should not jump
   BCS noError5b  ; Should jump
error5b:
   JMP error5b
noError5b:
   BEQ error5b    ; Should not jump
   BMI error5b    ; Should not jump

success:
   LDA #$FF
   JMP success


;ALU_ORA & X"35" & X"26" & X"00" & X"37" & X"00",
;ALU_AND & X"35" & X"26" & X"00" & X"24" & X"00",
;ALU_EOR & X"35" & X"26" & X"00" & X"13" & X"00",
;ALU_ADC & X"35" & X"26" & X"00" & X"5B" & X"00",
;ALU_STA & X"35" & X"26" & X"00" & X"35" & X"00",
;ALU_LDA & X"35" & X"26" & X"00" & X"26" & X"00",
;ALU_CMP & X"35" & X"26" & X"00" & X"35" & X"00",
;ALU_SBC & X"35" & X"26" & X"00" & X"0E" & X"01",
;
;-- Test of Zero and Sign (and carry unchanged)
;ALU_LDA & X"35" & X"00" & X"00" & X"00" & X"02",
;ALU_LDA & X"35" & X"00" & X"01" & X"00" & X"03",
;ALU_LDA & X"35" & X"80" & X"00" & X"80" & X"80",
;ALU_LDA & X"35" & X"80" & X"01" & X"80" & X"81",
;
;-- Test of ADC (carry)
;ALU_ADC & X"35" & X"26" & X"01" & X"5C" & X"00",
;ALU_ADC & X"35" & X"E6" & X"00" & X"1B" & X"01",
;ALU_ADC & X"35" & X"E6" & X"01" & X"1C" & X"01",
;
;-- Test of SBC (carry)
;ALU_SBC & X"35" & X"26" & X"01" & X"0F" & X"01",
;ALU_SBC & X"35" & X"E6" & X"00" & X"4E" & X"00",
;ALU_SBC & X"35" & X"E6" & X"01" & X"4F" & X"00"
