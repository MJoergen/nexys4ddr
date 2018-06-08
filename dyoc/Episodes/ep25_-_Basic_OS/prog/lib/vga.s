.setcpu		"6502"
.export		_vga_cursor_enable
.export		_vga_cursor_disable
.export     _curs_enable, _curs_inverted, _curs_cnt
.exportzp   _curs_pos

.segment	"DATA"

_curs_enable:
	.byte	$00
_curs_inverted:
	.byte	$00
_curs_cnt:
	.byte	$00

.segment	"ZEROPAGE"

_curs_pos:
	.res	2,$00       ; This must be placed in zero-page.

; ---------------------------------------------------------------
; void __near__ vga_cursor_enable (__near__ unsigned char *)
; ---------------------------------------------------------------

.segment	"CODE"

.proc	_vga_cursor_enable: near

	STA     _curs_pos
	STX     _curs_pos+1
	LDA     #$00
	STA     _curs_inverted
	LDA     #$02               ; Give it a low value, so that it will quickly invert.
	STA     _curs_cnt
	LDA     #$01
	STA     _curs_enable
   RTS

.endproc


; ---------------------------------------------------------------
; void __near__ vga_cursor_disable (void)
; ---------------------------------------------------------------

.segment	"CODE"

.proc	_vga_cursor_disable: near

	LDA     #$00
	STA     _curs_enable
	LDA     _curs_inverted
	BEQ     L0021

	LDY     #$00
	LDA     (_curs_pos),y
	ASL     a
	ADC     #$00
	ASL     a
	ADC     #$00
	ASL     a
	ADC     #$00
	ASL     a
	ADC     #$00
	STA     (_curs_pos),y
L0021:	RTS

.endproc

