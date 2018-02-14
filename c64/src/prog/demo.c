//
// This is a complete demo. Features demonstrated are:
// Keyboard input.
// Moving sprites.
// Horizontal scrolling text. TBD
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "circle.h"     // Routines to move the sprite around in a circle.

#define COL_LIGHT       0x6F   // 011_011_11
#define COL_DARK        0x44   // 010_001_00
#define COL_BLACK       0x00   // 000_000_00

// Forward declarations.
void __fastcall__ readFromKeyboard(void);

static void __fastcall__ clearScreen(void)
{
   // Clear the screen
   __asm__("LDA #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA #$80"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("LDA #$00"); 
   __asm__("TAX"); 
clear:
   __asm__("LDA #$20"); 
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("BCC %g", clear); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("CMP #$84"); 
   __asm__("BNE %g", clear); 
   __asm__("RTS"); 
} // end of clearScreen

static unsigned char irqA;
static unsigned char irqX;
static unsigned char irqCnt;

// The interrupt service routine.
void __fastcall__ irq(void)
{
   __asm__("STA %v", irqA);    // Store A register
   __asm__("TXA");
   __asm__("STA %v", irqX);    // Store X register

   __asm__("LDA %w", VGA_ADDR_IRQ);  // Clear IRQ assertion.

   circle_move();

   // Blink with cursor
   __asm__("LDA %v", irqCnt);
   __asm__("CLC");
   __asm__("ADC #$04");
   __asm__("STA %v", irqCnt);
   __asm__("BNE %g", end_irq);

   __asm__("LDX #$00");
   __asm__("LDA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("EOR #$20");
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 

end_irq:
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

   circle_init();

   //clearScreen();

   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);
   
   // Configure VGA interrupt
   __asm__("LDA #$F0"); 
   //__asm__("LDA #$00"); 
   __asm__("STA %w", VGA_ADDR_YLINE);             // Set the interrupt at past the end of the screen
   __asm__("LDA #$01"); 
   __asm__("STA %w", VGA_ADDR_MASK);
   __asm__("LDA %w", VGA_ADDR_IRQ);               // Clear any pending IRQ
   __asm__("LDA #$00"); 
   __asm__("STA %v", irqCnt);
   __asm__("CLI"); 

   // Reset the current screen pointer
   __asm__("LDA #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA #$80"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 

loop:
   __asm__("JSR %v", readFromKeyboard);      // This is a blocking call; it won't return until a valid keypress is detected.

   // Now write it to the screen
   __asm__("LDX #$00"); 
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 

   // Update screen pointer
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("CMP #$84"); 
   __asm__("BNE %g", noWrap); 
   __asm__("LDA #$80"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
noWrap:

   goto loop;  // Just do an endless loop.
} // end of reset

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

