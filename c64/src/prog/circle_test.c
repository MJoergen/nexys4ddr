//
// This is a complete demo. Features demonstrated are:
// Keyboard input.
// Moving sprites.
// Horizontal scrolling text. TBD
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "circle.h"     // Routines to move the sprite around in a circle.
#include "smult.h"      // Signed 8-bit multiplication.

#define COL_LIGHT       0x6F   // 011_011_11
#define COL_DARK        0x44   // 010_001_00
#define COL_BLACK       0x00   // 000_000_00

static unsigned char irqA;
static unsigned char irqX;
static unsigned char irqY;
static unsigned char irqCnt;

#define YPOS_LINE1 2

// The interrupt service routine.
void __fastcall__ irq(void)
{
   __asm__("STA %v", irqA);    // Store A register
   __asm__("TXA");
   __asm__("STA %v", irqX);    // Store X register
   __asm__("TYA");
   __asm__("STA %v", irqY);    // Store Y register

   circle_move();

   __asm__("LDA %v", irqY);    // Restore Y
   __asm__("TAY");
   __asm__("LDA %v", irqX);    // Restore X
   __asm__("TAX");
   __asm__("LDA %v", irqA);    // Restore A

   __asm__("RTI");
} // end of irq

// Entry point after CPU reset
void __fastcall__ reset(void)
{
   __asm__("SEI");                           // Disable all interrupts
   __asm__("LDX #$FF");
   __asm__("TXS");                           // Reset stack pointer

   smult_init();
   circle_init();

   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);
   
   // Configure VGA interrupt
   __asm__("LDA #%b", YPOS_LINE1); 
   __asm__("STA %w", VGA_ADDR_YLINE);             // Set the interrupt at the end of the first line
   __asm__("LDA #$01"); 
   __asm__("STA %w", VGA_ADDR_MASK);
   __asm__("LDA %w", VGA_ADDR_IRQ);               // Clear any pending IRQ
   __asm__("LDA #$00"); 
   __asm__("STA %v", irqCnt);
   __asm__("CLI"); 

loop:
   goto loop;  // Just do an endless loop.
} // end of reset

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

