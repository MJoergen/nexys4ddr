.setcpu		"6502"
.export		_vga_cursor_enable
.export		_vga_cursor_disable
.export		_vga_isr

BLINK_TIME = $10     ; 60 units in a second.

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


; ---------------------------------------------------------------
; void __near__ vga_isr (void)
; ---------------------------------------------------------------

.segment	"CODE"

.proc	_vga_isr: near

	LDX     _curs_enable
	BEQ     L003F

	DEC     _curs_cnt
	BNE     L003F

   PHA
	LDA     #BLINK_TIME
	STA     _curs_cnt
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
	LDA     _curs_inverted
	EOR     #$FF
	STA     _curs_inverted
   PLA

L003F:	RTS

.endproc


