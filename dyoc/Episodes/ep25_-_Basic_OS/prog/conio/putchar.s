.setcpu		"6502"
;.importzp	sp, sreg, regsave, regbank
;.importzp	tmp1, tmp2, tmp3, tmp4, ptr1, ptr2, ptr3, ptr4
.importzp	_curs_pos
;.autoimport
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

	ldy     #$00
	sta     (_curs_pos),y

   inc     _curs_pos
   bne     end
   inc     _curs_pos+1
end:

   rts

.endproc

