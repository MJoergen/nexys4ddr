	.setcpu		"6502"

   .export init, _exit
   .import _main

   .export __STARTUP__ : absolute = 1     ; Mark as startup
   .import __RAM_START__, __RAM_SIZE__    ; Linker generated

   .import copydata, zerobss, initlib, donelib

   .include "zeropage.inc"

; ---------------------------------------------------------------------------
; Place the startup code in a special segment

.segment	"STARTUP"

; ---------------------------------------------------------------------------
; Entry point for a hardware reset. Referenced in lib/vectors.s

init:

; ---------------------------------------------------------------------------
; Setup processor mode

   SEI                     ; Disable interrupts
   CLD                     ; Clear decimal mode
   LDX #$FF                ; Reset stack pointer
   TXS

; ---------------------------------------------------------------------------
; Set cc65 argument stack pointer

   LDA #<(__RAM_START__ + __RAM_SIZE__)
   STA sp
   LDA #>(__RAM_START__ + __RAM_SIZE__)
   STA sp+1   

; ---------------------------------------------------------------------------
; Initialize memory storage

   JSR zerobss             ; Clear BSS segment
   JSR copydata            ; Initialize DATA segment
   JSR initlib             ; Run constructors

; ---------------------------------------------------------------------------
; Call C-function main()

   JSR _main

; ---------------------------------------------------------------------------
; Back from main (this is also entry point for the C-function exit()):

_exit:
   SEI                     ; Disable interrupts
   JSR donelib             ; Run destructors
halt:
   JMP halt

