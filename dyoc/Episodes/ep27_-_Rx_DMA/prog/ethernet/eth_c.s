; Wrapper for Ethernet driver

.export _eth_init
.export _eth_rx

; It is assumed that the field eth_inp_len comes immediately before eth_inp.
.export eth_inp_len
.export eth_inp

.export _eth_inp_len
.export _eth_inp

.import eth_init
.import eth_rx

_eth_inp_len = eth_inp_len
_eth_inp     = eth_inp

.bss

eth_inp_len: .res 2
eth_inp:     .res 1514

.code
_eth_init:
      jmp eth_init

; Returns zero if a packet is ready, nonzero otherwise.
_eth_rx:
      jsr eth_rx
      lda #0
      rol a
      rts

