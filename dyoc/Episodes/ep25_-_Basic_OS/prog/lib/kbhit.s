.export     _kbhit
.import     _kbd_buffer_count   ; Defined in lib/keyboard.c

.proc _kbhit

      ldx #0                     ; High byte of return is always zero
      lda _kbd_buffer_count      ; Get number of characters
      beq end
      lda #1
end:  rts   

.endproc

