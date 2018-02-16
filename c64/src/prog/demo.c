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

static void __fastcall__ clearLine(void)
{
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
   __asm__("CMP #$27"); 
   __asm__("BEQ %g", rts); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("JMP %g", clear);
rts:
   __asm__("RTS"); 
} // end of clearLine

static void __fastcall__ deleteChar(void)
{
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("STA %b", ZP_STOP);                  // Store current position
   __asm__("LDA #$27"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO);         // Move to end of line
   __asm__("LDX #$00"); 
   __asm__("LDA #$20"); 
   __asm__("TAY");                              // Put ' ' in Y

loop:
   __asm__("LDA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("STA %b", ZP_TEMP); 
   __asm__("TYA"); 
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CMP %b", ZP_STOP); 
   __asm__("BEQ %g", rts); 
   __asm__("SEC"); 
   __asm__("SBC #$01"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_TEMP); 
   __asm__("TAY"); 
   __asm__("JMP %g", loop); 
rts:
   __asm__("RTS"); 
} // end of deleteChar

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

static void __fastcall__ updateBuffer(void)
{
   // First check for various control characters
   __asm__("CMP #$08");
   __asm__("BEQ %g", backSpace);
   __asm__("CMP #$7F");
   __asm__("BEQ %g", delete);
   __asm__("CMP #$1B");
   __asm__("BEQ %g", left);
   __asm__("CMP #$1A");
   __asm__("BEQ %g", right);
   __asm__("CMP #$02");
   __asm__("BEQ %g", home);
   __asm__("CMP #$03");
   __asm__("BEQ %g", end);
   __asm__("CMP #$0D");
   __asm__("BEQ %g", enter);
   __asm__("CMP #$00");
   __asm__("BNE %g", normal);
rts:
   __asm__("RTS");

backSpace:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("BEQ %g", rts);    // Ignore, if we are at beginning of line
   __asm__("SEC");            // Move cursor one left.
   __asm__("SBC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_LO);   // Continue with delete

delete:
   __asm__("JSR %v", deleteChar);
   __asm__("RTS");

left:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("BEQ %g", rts);    // Ignore, if we are at beginning of line
   __asm__("SEC");            // Move cursor one left.
   __asm__("SBC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("RTS");

right:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CMP #$27");
   __asm__("BEQ %g", rts);    // Ignore, if we are at end of line
   __asm__("CLC");            // Move cursor one right.
   __asm__("ADC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("RTS");

home:
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("RTS");

end:
   __asm__("LDA #$27");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("RTS");

enter:
   __asm__("JSR %v", clearLine);
   __asm__("JMP %g", home);

normal:
   __asm__("LDX #$00"); 
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("JMP %g", right);

} // end of updateBuffer


// Entry point after CPU reset
void __fastcall__ reset(void)
{
   __asm__("SEI");                           // Disable all interrupts
   __asm__("LDX #$FF");
   __asm__("TXS");                           // Reset stack pointer

   circle_init();

   clearScreen();

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
   __asm__("JSR %v", updateBuffer);

   goto loop;  // Just do an endless loop.
} // end of reset

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

