           ; This short assembly routine generates a circle with a given
           ; radius and a given centre
           ; It uses the semi-implicit Euler method:
           ;   x1 = x0 - y0*dt
           ;   y1 = y0 + x1*dt
           ; We are using the value dt = 1/256.
           ;
           ; Zero-page registers used
           ; $00 XLO
           ; $01 XHI
           ; $02 YLO
           ; $03 YHI
           ;
           ; The program is assumed to start at 0x0400.
           ;
A9 40      ;           LDA #$40  ; Load radius ...
85 01      ;           STA $01   ; ... into XHI
A5 03      ;  loop:    LDA $03   ; Load YHI
18         ;           CLC
65 00      ;           ADC $00   ; Add to XLO
85 00      ;           STA $00   ; Store in XLO
A5 01      ;           LDA $01   ; Possibly ...
69 00      ;           ADC #$00  ; ... increment ...
85 01      ;           STA $01   ; ... XHI
18         ;           CLC
65 02      ;           ADC $02   ; Add to YLO
85 02      ;           STA $02   ; Store in YLO
A5 03      ;           LDA $03   ; Possibly ...
69 00      ;           ADC #$00  ; ... increment ...
85 03      ;           STA $03   ; ... YHI
4C 04 04   ;           JMP loop  ; Repeat


