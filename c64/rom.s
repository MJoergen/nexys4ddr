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
           ; Thus, the integer parts are stored in $01 and $03, while the fractional
           ; parts are stored in $00 and $02.
           ;
           ; The program is assumed to start at 0xFC00.
           ;
A9 00      ;  FC 00          LDA #$00  ; Initialize
85 00      ;  FC 02          STA $00
85 02      ;  FC 04          STA $02
85 03      ;  FC 06          STA $03
A9 40      ;  FC 08          LDA #$40  ; Load radius ...
85 01      ;  FC 0A          STA $01   ; ... into XHI
A5 00      ;  FC 0C loop:    LDA $00   ; Load XLO
18         ;  FC 0E          CLC
E5 03      ;  FC 0F          SBC $03   ; Subtract YHI
85 00      ;  FC 11          STA $00   ; Store in XLO
A5 01      ;  FC 13          LDA $01   ; Possibly ...
E9 00      ;  FC 15          SBC #$00  ; ... decrement ...
85 01      ;  FC 17          STA $01   ; ... XHI
18         ;  FC 19          CLC
65 02      ;  FC 1A          ADC $02   ; Add to YLO
85 02      ;  FC 1C          STA $02   ; Store in YLO
A5 03      ;  FC 1E          LDA $03   ; Possibly ...
69 00      ;  FC 20          ADC #$00  ; ... increment ...
85 03      ;  FC 22          STA $03   ; ... YHI
4C 0C FC   ;  FC 24          JMP loop  ; Repeat


