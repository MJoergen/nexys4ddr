	.setcpu		"6502"

   .export init, _exit
   .import _main, _clrscr

   .export __STARTUP__ : absolute = 1     ; Mark as startup
   .import __RAM_START__, __RAM_SIZE__    ; Linker generated

   .import copydata, zerobss, initlib, donelib

   .include "zeropage.inc"

; ---------------------------------------------------------------------------
; Place the startup code in a special segment

.segment	"STARTUP"

; ---------------------------------------------------------------------------
; Extra defines needed by the startup code
; These must match the corresponding symbols in include/memorymap.h
; and the assignment in lib/irq.s.

IRQ_STATUS     = $7FFF
IRQ_MASK       = $7FDF

IRQ_TIMER_NUM  = 0
IRQ_VGA_NUM    = 1
IRQ_KBD_NUM    = 2

IRQ_TIMER_MASK = 1 << IRQ_TIMER_NUM
IRQ_VGA_MASK   = 1 << IRQ_VGA_NUM
IRQ_KBD_MASK   = 1 << IRQ_KBD_NUM

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
;   JSR _clrscr             ; Clear screen

; ---------------------------------------------------------------------------
; Enable timer interrupt

   LDA #IRQ_TIMER_MASK | IRQ_VGA_MASK | IRQ_KBD_MASK
   STA IRQ_MASK            ; Enable timer and keyboard interrupt
   LDA IRQ_STATUS          ; Clear any pending interrupts
   CLI                     ; Enable interrupt handling

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

