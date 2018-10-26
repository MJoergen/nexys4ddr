; Wrapper for Ethernet driver

.export _eth_init
.export _eth_rx
.export _eth_tx

; It is assumed that the field eth_inp_len comes immediately before eth_inp.
.export eth_inp_len
.export eth_inp
.export _eth_inp_len
.export _eth_inp

; It is assumed that the field eth_out_len comes immediately before eth_out.
.export eth_outp_len
.export eth_outp
.export _eth_outp_len
.export _eth_outp

.import eth_init
.import eth_rx
.import eth_tx

_eth_inp_len = eth_inp_len
_eth_inp     = eth_inp
_eth_outp_len = eth_outp_len
_eth_outp     = eth_outp

.bss

eth_inp_len: .res 2
eth_inp:     .res 1514

eth_outp_len: .res 2
eth_outp:     .res 1514

.code
_eth_init:
      jmp eth_init

; Returns zero if a packet is ready, nonzero otherwise.
_eth_rx:
      jsr eth_rx
      lda #0
      rol a
      rts

_eth_tx:
      jmp eth_tx

