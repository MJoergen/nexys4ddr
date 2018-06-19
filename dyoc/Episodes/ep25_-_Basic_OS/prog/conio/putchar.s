.setcpu		"6502"
.importzp	sp, sreg, regsave, regbank
.importzp	tmp1, tmp2, tmp3, tmp4, ptr1, ptr2, ptr3, ptr4
.import		_pos_x
.import		_pos_y
.autoimport
.export		_putchar

; This file must be written in assembler, because
; some of the calling functions assume that
; prt1 is unused. So therefore this function
; is made to use ptr3 instead.

; ---------------------------------------------------------------
; void __near__ putchar (unsigned char)
; ---------------------------------------------------------------

.segment	"CODE"

.proc	_putchar: near

.segment	"CODE"

	jsr     pusha
	lda     _pos_y
	jsr     pusha0
	lda     #$50
	jsr     tosumula0
	clc
	adc     _pos_x
	bcc     L0006
	inx
L0006:	sta     ptr3
   txa
   clc
	adc     #$80
	sta     ptr3+1
	ldy     #$00
	lda     (sp),y
	sta     (ptr3),y
	jmp     incsp1

.endproc

