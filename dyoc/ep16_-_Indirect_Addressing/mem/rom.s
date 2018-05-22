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
; Test 11 : Test INC
   LDA #$FF
   STA $02
   CLC
   INC $02
   BEQ noError11
error11:
   LDA #$11
   JMP error11
noError11:
   BMI error11
   BCS error11
   LDA $02
   BNE error11

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 12 : Test ASL (register)
   LDA #$20
   SEC
   ASL A
   BCC noError12
error12:
   LDA #$12
   JMP error12
noError12:
   BMI error12
   BEQ error12
   CMP #$40
   BNE error12

   ASL A
   BCS error12
   BPL error12
   BEQ error12
   CMP #$80
   BNE error12

   ASL A
   BCC error12
   BMI error12
   BNE error12
   CMP #$00
   BNE error12

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 13 : Test ASL (memory)
   LDA #$41
   STA $02
   LDA #$23
   SEC
   ASL $02
   BMI noError13
error13:
   LDA #$13
   JMP error13
noError13:
   BCS error13
   LDA $02
   CMP #$82
   BNE error13

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 14 : Test BIT
   LDA #$C0
   STA $02
   SEC
   LDA #$21
   BIT $02
   BCS noError14
error14:
   LDA #$14
   JMP error14
noError14:
   BPL error14
   BVC error14
   CMP #$21
   BNE error14

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 15 : Test X-register
   LDA #$78
   LDX #$87
   CMP #$78    ; Verify A-register is not destroyed
   BEQ noError15
error15:
   LDA #$15
   JMP error15
noError15:
   TXA
   CMP #$87
   BNE error15
   INX
   CPX #$87
   BEQ error15
   CPX #$88
   BNE error15
   DEX
   CPX #$88
   BEQ error15
   CPX #$87
   BNE error15

   PHA
   LDA #$78
   PHA
   TSX
   INX
   TXS
   PLA
   CMP #$87
   BNE error15

   LDX #$87
   STX $02
   LDX #$78
   STX $03FF
   LDA $02
   CMP #$87
   BNE error15
   LDA $03FF
   CMP #$78
   BNE error15

   LDA #$98
   STA $02
   LDA #$77
   STA $03FF
   LDX $02
   CPX #$98
   BNE error15
   LDX $03FF
   CMP #$77
   BNE error15

   LDA #$98
   TAX
   CPX $02
   BNE error15
   LDA #$77
   TAX
   CPX $03FF
   BNE error15

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 16 : Test Y-register
   LDA #$23
   TAY
   LDA #$34
   CPY #$23
   BEQ noError16
error16:
   LDA #$16
   JMP error16
noError16:
   INY
   CPY #$23
   BEQ error16
   CPY #$24
   BNE error16
   DEY
   CPY #$24
   BEQ error16
   CPY #$23
   BNE error16

   LDY #$21
   CPY #$21
   BNE error16

   STY $02
   LDY #$43
   STY $03FF
   LDY #$21
   CPY $02
   BNE error16
   LDY #$43
   CPY $03FF
   BNE error16

   CMP #$34
   BNE error16

   LDY $02
   TYA
   CMP #$21
   BNE error16
   LDY $03FF
   TYA
   CMP #$43
   BNE error16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 17 : Test a,X and a,Y addressing modes
   LDA #$11
   STA $0320
   LDX #$10
   LDA #$DD
   LDA $0310,X
   BNE noError17
error17:
   LDA #$17
   JMP error17
noError17:
   BMI error17
   CMP #$11
   BNE error17

   ASL $0310,X
   LDA $0310,X
   CMP #$22
   BNE error17

   LDA #$DD
   LDX #$30
   LDA $02F0,X
   CMP #$22
   BNE error17

   LDA #$DD
   LDY #$10
   LDA $0310,Y
   CMP #$22
   BNE error17

   LDA #$DD
   LDY #$30
   LDA $02F0,Y
   CMP #$22
   BNE error17

   LDX $02F0,Y ; $0320
   CPX #$22
   BNE error17
   LDX #$10
   LDY $0310,X ; $0320
   CPY #$22
   BNE error17

   LDX #$40
   LDY #$50
   STX $20,Y   ; $70
   LDA $70
   CMP #$40
   BNE error17

   STY $20,X   ; $60
   LDA $60
   CMP #$50
   BNE error17

   LDA #$33
   STA $70
   LDA #$44
   LDY $30,X   ; $70
   CPY #$33
   BNE error17

   LDY #$20
   LDA #$33
   STA $50
   LDA #$44
   LDX $30,Y   ; $50
   CPX #$33
   BNE error17

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Test 18 : Test (d,X) addressing modes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; All tests were a success
success:
   LDA #$FF
   JMP success

