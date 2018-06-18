.export _textcolor, _bgcolor, _bordercolor

.segment	"CODE"

VGA_PALETTE = $7FC0

_textcolor:
   ldx VGA_PALETTE+15      ; get old value
   sta VGA_PALETTE+15      ; set new value
   txa
   rts

_bgcolor:
   ldx VGA_PALETTE         ; get old value
   sta VGA_PALETTE         ; set new value
   txa
   rts

_bordercolor:
   rts
