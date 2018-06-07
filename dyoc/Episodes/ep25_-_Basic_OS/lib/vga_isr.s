.setcpu		"6502"
.export		vga_isr
.import     _curs_enable, _curs_cnt, _curs_inverted
.importzp   _curs_pos

BLINK_TIME = $10     ; 60 units in a second.

.segment	"CODE"

vga_isr:

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


