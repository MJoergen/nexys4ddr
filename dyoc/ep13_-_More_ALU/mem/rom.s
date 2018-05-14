	.setcpu		"6502"

.segment	"CODE"

; This is a self-verifying assembly program that will check for correct
; functionality of the individual instructions.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 01 : Test flags S and Z when loading $00.
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 02 : Test flags S and Z when loading $FF.
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 03 : Test flag C.
; Conditional branch forward
   CLC
   LDA #$FF
   BCS error3     ; Should not jump
   BCC noError3   ; Should jump
error3:
   LDA #$03
   JMP error3
noError3:
   SEC
   LDA #$FF
   BCC error3     ; Should not jump
   BCS noError3a  ; Should jump
   JMP error3
noError3a:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 04 : Test conditional branching backward
   JMP noError4
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 05 : Test compare
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 06 : Test ALU using immediate operands
   LDA #$35
   ORA #$26
   CMP #$37
   BEQ noError6a
error6:
   LDA #$06
   JMP error6
noError6a:

   LDA #$35
   AND #$26
   CMP #$24
   BNE error6

   LDA #$35
   EOR #$26
   CMP #$13
   BNE error6

   LDA #$35
   CLC
   ADC #$26
   CMP #$5B
   BNE error6

   LDA #$35
   SEC
   ADC #$26
   CMP #$5C
   BNE error6

   LDA #$35
   SEC
   SBC #$26
   CMP #$0F
   BNE error6

   LDA #$35
   CLC
   SBC #$26
   CMP #$0E
   BNE error6

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 07 : Test absolute addressing
   LDA #$35
   STA $07F0
   LDA #$53
   STA $07F1
   LDA $07F0
   CMP #$35
   BEQ noError7
error7:
   LDA #$07
   JMP error7
noError7:
   LDA $07F0
   CLC
   ADC $07F1
   CMP #$88
   BNE error7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 08 : Test zero page addressing
   LDA #$35
   STA $F0
   LDA #$53
   STA $F1
   LDA $F0
   CMP #$35
   BEQ noError8
error8:
   LDA #$08
   JMP error8
noError8:
   LDA $F0
   CLC
   ADC $F1
   CMP #$88
   BNE error8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 09 : Test PUSH and PULL
   LDA #$11
   PHA
   LDA #$22
   PHA
   LDA #$11
   CMP $01FF
   BEQ noError9
error9:
   LDA #$09
   JMP error9
noError9:
   PLA
   CMP #$22
   BNE error9
   CMP $01FE
   BNE error9
   PLA
   CMP #$11
   BNE error9

   LDA #$00
   SEC         ; S=0, Z=1, C=1
   PHP
   LDA #$FF
   CLC         ; S=1, Z=0, C=0         
   PLP
   BCC error9
   BNE error9
   BMI error9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 10 : Test JSR and RTS
   JSR noError10a ; This should never return in this test
error10:
   LDA #$10
   JMP error10

noError10a:
   PLA
   STA $00
   PLA
   STA $01
   LDA $00
   CLC
   ADC #$01
   STA $00
   LDA $01
   ADC #$00
   STA $01
   CMP #>error10
   BNE error10
   LDA $00
   CMP #<error10
   BNE error10
   JSR noError10b    ; This should return
   JMP noError10c
noError10b:
   RTS
   JMP error10
noError10c:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; All tests very a success
success:
   LDA #$FF
   JMP success

