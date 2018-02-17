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
   __asm__("TAY"); 
clear:
   __asm__("LDA #$20"); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("INY"); 
   __asm__("BNE %g", clear); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
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
   __asm__("TAY"); 
clear:
   __asm__("LDA #$20"); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("TYA"); 
   __asm__("CMP #$27"); 
   __asm__("BEQ %g", rts); 
   __asm__("INY"); 
   __asm__("JMP %g", clear);
rts:
   __asm__("RTS"); 
} // end of clearLine

static void __fastcall__ copyLine(void)
{
   __asm__("LDA #$27"); 
   __asm__("TAX"); 
loop:
   __asm__("LDA %w,X", VGA_ADDR_SCREEN);        // Copy from line 0
   __asm__("STA %w,X", VGA_ADDR_SCREEN+40);     // to line 1
   __asm__("DEX"); 
   __asm__("BPL %g", loop); 
   __asm__("RTS"); 
} // end of copyLine

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
static unsigned char irqY;
static unsigned char irqCnt;

#define YPOS_LINE1 (1*13 - 1)
#define YPOS_LINE2 (2*13 - 1)

// The interrupt service routine.
void __fastcall__ irq(void)
{
   __asm__("STA %v", irqA);    // Store A register
   __asm__("TXA");
   __asm__("STA %v", irqX);    // Store X register
   __asm__("TYA");
   __asm__("STA %v", irqY);    // Store Y register

   __asm__("LDA %w", VGA_ADDR_IRQ);  // Clear IRQ assertion.

   __asm__("LDA %w", VGA_ADDR_YLINE);
   __asm__("CMP #%b", YPOS_LINE1);
   __asm__("BNE %g", clearScroll);

   __asm__("LDA %b", ZP_XSCROLL);      // Enable scroll of line 1
   __asm__("STA %w", VGA_ADDR_XSCROLL);
   __asm__("LDA #%b", YPOS_LINE2);  // Set interrupt at end of line 2
   __asm__("STA %w", VGA_ADDR_YLINE);
   __asm__("JMP %g", end_irq);

clearScroll:
   __asm__("LDA #$00");             // Clear scroll
   __asm__("STA %w", VGA_ADDR_XSCROLL);
   __asm__("LDA #%b", YPOS_LINE1);  // Set interrupt at end of line 1
   __asm__("STA %w", VGA_ADDR_YLINE);

   __asm__("LDA %b", ZP_CNT);
   __asm__("CLC");
   __asm__("ADC #$40");
   __asm__("STA %b", ZP_CNT);
   __asm__("BNE %g", circle); // Time to shift a pixel ?

   // Ok, we shift one pixel.
   __asm__("LDA %b", ZP_XSCROLL);
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("AND #$0F");
   __asm__("STA %b", ZP_XSCROLL);
   __asm__("CMP #$0F");
   __asm__("BNE %g", circle); // Time to shift a whole byte ?

   // Ok, we shift a whole byte.
   __asm__("LDA %w", VGA_ADDR_SCREEN+40); // Keep left-most character
   __asm__("TAY");

   __asm__("LDA #%b", 40);
more_scroll:
   __asm__("TAX");
   __asm__("LDA %w,X", VGA_ADDR_SCREEN+1);
   __asm__("STA %w,X", VGA_ADDR_SCREEN);
   __asm__("TXA");
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("CMP #%b", 79);
   __asm__("BNE %g", more_scroll);

   // Wrap around
   __asm__("TYA");
   __asm__("STA %w", VGA_ADDR_SCREEN+79);

circle:
   circle_move();

   // Blink with cursor
   __asm__("LDA %v", irqCnt);
   __asm__("CLC");
   __asm__("ADC #$04");
   __asm__("STA %v", irqCnt);
   __asm__("BPL %g", make_cursor);

   __asm__("LDX #$00"); 
   __asm__("LDA %b", ZP_CURSOR_CHAR);  // Restore character
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("JMP %g", end_irq);

make_cursor:
   __asm__("LDX #$00"); 
   __asm__("LDA #$00");        // Cursor character
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 

end_irq:
   __asm__("LDA %v", irqY);    // Restore Y
   __asm__("TAY");
   __asm__("LDA %v", irqX);    // Restore X
   __asm__("TAX");
   __asm__("LDA %v", irqA);    // Restore A

   __asm__("RTI");
} // end of irq

static void __fastcall__ updateBuffer(void)
{
   // Restore character
   __asm__("TAY"); 
   __asm__("LDX #$00"); 
   __asm__("LDA %b", ZP_CURSOR_CHAR);
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("LDA #$80");
   __asm__("STA %v", irqCnt);             // Prevent IRQ from overwriting character
   __asm__("TYA"); 

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
   __asm__("RTS");

backSpace:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("BEQ %g", rts);    // Ignore, if we are at beginning of line
   __asm__("SEC");            // Move cursor one left.
   __asm__("SBC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_LO);   // Continue with delete

delete:
   __asm__("JSR %v", deleteChar);

rts:
   __asm__("LDX #$00"); 
   __asm__("LDA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("STA %b", ZP_CURSOR_CHAR);
   __asm__("LDA #$00");
   __asm__("STA %v", irqCnt);

   __asm__("RTS");

left:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("BEQ %g", rts);    // Ignore, if we are at beginning of line
   __asm__("SEC");            // Move cursor one left.
   __asm__("SBC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("JMP %g", rts);

right:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CMP #$27");
   __asm__("BEQ %g", rts);    // Ignore, if we are at end of line
   __asm__("CLC");            // Move cursor one right.
   __asm__("ADC #$01");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("JMP %g", rts);

home:
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("JMP %g", rts);

end:
   __asm__("LDA #$27");
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("JMP %g", rts);

enter:
   __asm__("JSR %v", copyLine);
   __asm__("JSR %v", clearLine);
   __asm__("JMP %g", home);

normal:
   __asm__("LDX #$00"); 
   __asm__("STA (%b, X)", ZP_SCREEN_POS_LO); 
   __asm__("STA %b", ZP_CURSOR_CHAR);
   __asm__("LDA #$00");
   __asm__("STA %v", irqCnt);
   __asm__("JMP %g", right);

} // end of updateBuffer


// Entry point after CPU reset
void __fastcall__ reset(void)
{
   __asm__("SEI");                           // Disable all interrupts
   __asm__("LDX #$FF");
   __asm__("TXS");                           // Reset stack pointer

   smult_init();
   circle_init();
   clearScreen();

   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);
   
   // Initialize X scroll
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_CNT);
   __asm__("STA %b", ZP_XSCROLL);
   __asm__("STA %w", VGA_ADDR_XSCROLL);

   // Configure VGA interrupt
   __asm__("LDA #%b", YPOS_LINE1); 
   __asm__("STA %w", VGA_ADDR_YLINE);             // Set the interrupt at the end of the first line
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
   __asm__("LDA $8000");                           // Read first character from screen memory (where cursor is).
   __asm__("STA %b", ZP_CURSOR_CHAR);

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

