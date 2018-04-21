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

// This provides a mapping from RGB to RGB, where each mapping only
// changes the colour by a minimal amount.
// This is a 3D Hilbert Curve, adapted from
// https://stackoverflow.com/questions/14519267/algorithm-for-generating-a-3d-hilbert-space-filling-curve-in-python
static const unsigned char trans[256] = {
   0x01, 0x21, 0x06, 0x02, 0x08, 0x04, 0x26, 0x03,
   0x28, 0x0a, 0x2a, 0x07, 0x0d, 0x2d, 0x0f, 0x2f,
   0x11, 0x31, 0x13, 0x17, 0x10, 0x14, 0x36, 0x16,
   0x19, 0x39, 0x1b, 0x1f, 0x18, 0x1c, 0x3e, 0x1e,
   0x24, 0x20, 0x23, 0x27, 0x25, 0x05, 0x22, 0x47,
   0x2c, 0x09, 0x2e, 0x0b, 0x0c, 0x29, 0x0e, 0x2b,
   0x50, 0x30, 0x12, 0x32, 0x35, 0x15, 0x37, 0x3b,
   0x34, 0x38, 0x1a, 0x3a, 0x3d, 0x1d, 0x3f, 0x5f,
   0x41, 0x61, 0x46, 0x42, 0x40, 0x44, 0x66, 0x43,
   0x68, 0x4d, 0x6a, 0x4f, 0x48, 0x6d, 0x4a, 0x6f,
   0x70, 0x52, 0x72, 0x33, 0x55, 0x75, 0x57, 0x77,
   0x5c, 0x58, 0x5e, 0x5a, 0x3c, 0x59, 0x7e, 0x5b,
   0x80, 0x60, 0x63, 0x67, 0x65, 0x45, 0x62, 0x6b,
   0x64, 0x49, 0x69, 0x4b, 0x4c, 0x6c, 0x4e, 0x6e,
   0x74, 0x51, 0x76, 0x53, 0x54, 0x71, 0x56, 0x73,
   0x79, 0x7d, 0x7b, 0x7f, 0x78, 0x5d, 0x7a, 0x00,
   0xa0, 0x82, 0x86, 0xa3, 0x85, 0xa5, 0x87, 0x83,
   0xa8, 0x88, 0x8e, 0x8a, 0x90, 0xad, 0x8d, 0x8b,
   0xb0, 0x92, 0x96, 0xb3, 0x95, 0xb5, 0x97, 0x93,
   0xb8, 0x98, 0x9e, 0x9a, 0x7c, 0xbd, 0x9d, 0x9b,
   0xa4, 0x81, 0xc2, 0xa7, 0x84, 0xa1, 0xa2, 0xa6,
   0xac, 0x89, 0xab, 0xaf, 0x8c, 0xa9, 0xaa, 0x8f,
   0xb4, 0x91, 0xd2, 0xb7, 0x94, 0xb1, 0xb2, 0xb6,
   0xbc, 0x99, 0xbb, 0xbf, 0x9c, 0xb9, 0xba, 0x9f,
   0xc1, 0xc5, 0xc6, 0xe3, 0xe4, 0xc4, 0xc7, 0xc3,
   0xc9, 0xcd, 0xce, 0xca, 0xec, 0xcc, 0xae, 0xcb,
   0xd1, 0xd5, 0xd6, 0xf3, 0xf4, 0xd4, 0xd7, 0xd3,
   0xd9, 0xdd, 0xde, 0xda, 0xfc, 0xdc, 0xbe, 0xdb,
   0xc0, 0xe0, 0xe1, 0xe7, 0xe5, 0xe9, 0xe2, 0xe6,
   0xc8, 0xe8, 0xeb, 0xef, 0xed, 0xee, 0xea, 0xcf,
   0xd0, 0xf0, 0xf1, 0xf7, 0xf5, 0xf9, 0xf2, 0xf6,
   0xd8, 0xf8, 0xfb, 0xff, 0xfd, 0xfe, 0xfa, 0xdf};

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


static void __fastcall__ resetColorLine(void)
{
   __asm__("LDA #%b", 39);
   __asm__("TAX");
loop:
   __asm__("ROL A");
   __asm__("ADC #$BA");
   __asm__("STA %w,X", MEM_COL+3*40);
   __asm__("DEX");
   __asm__("BPL %g", loop);

} // end of resetColorLine


static void __fastcall__ copyLine(void)
{
   __asm__("LDA #$27"); 
   __asm__("TAX"); 
loop:
   __asm__("LDA %w,X", VGA_ADDR_SCREEN);        // Copy from line 0
   __asm__("STA %w,X", VGA_ADDR_SCREEN+3*40);     // to line 3
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
static unsigned char irqBgStart;

#define YPOS_LINE1 (3*13 - 1)
#define YPOS_LINE2 (4*13 - 1)

// The interrupt service routine.
void __fastcall__ irq(void)
{
   // Store registers
   __asm__("STA %v", irqA);
   __asm__("TXA");
   __asm__("STA %v", irqX);
   __asm__("TYA");
   __asm__("STA %v", irqY);

   // Clear IRQ assertion
   __asm__("LDA %w", VGA_ADDR_IRQ);
   __asm__("STA %w", VGA_ADDR_IRQ);

   // Update background colour
   __asm__("LDA %w", VGA_ADDR_BGCOL);
   __asm__("TAX");
   __asm__("LDA %v,X", trans);
   __asm__("STA %w", VGA_ADDR_BGCOL);

   // Set interrupt to next line
   __asm__("LDA %w", VGA_ADDR_YLINE);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %w", VGA_ADDR_YLINE);

   // Check if end of screen
   __asm__("CMP #%b", 241U);
   __asm__("BEQ %g", bgRestart);

   // Check if scrolling should be enabled
   __asm__("CMP #%b", YPOS_LINE1+1);
   __asm__("BEQ %g", scrollStart);

   // Check if scrolling should be disabled
   __asm__("CMP #%b", YPOS_LINE2+1);
   __asm__("BEQ %g", scrollEnd);

end_irq:
   // Restore registers
   __asm__("LDA %v", irqY);
   __asm__("TAY");
   __asm__("LDA %v", irqX);
   __asm__("TAX");
   __asm__("LDA %v", irqA);
   __asm__("RTI");

bgRestart:
   __asm__("LDA %v", irqBgStart);
   __asm__("STA %w", VGA_ADDR_BGCOL);
   __asm__("JMP %g", end_irq);

scrollStart:
   __asm__("LDA %b", ZP_XSCROLL);      // Enable scroll of line 1
   __asm__("STA %w", VGA_ADDR_XSCROLL);
   __asm__("JMP %g", end_irq);

scrollEnd:
   __asm__("LDA #$00");             // Clear scroll
   __asm__("STA %w", VGA_ADDR_XSCROLL);

   // Here is reached once every frame, i.e. 60 times pr. second.

   __asm__("LDA %b", ZP_CNT);
   __asm__("AND #$40");
   __asm__("BEQ %g", skipTrans);

   // Here is reached 30 times pr. second.
   __asm__("LDA %v", irqBgStart);
   __asm__("TAX");
   __asm__("LDA %v,X", trans);
   __asm__("STA %v", irqBgStart);

skipTrans:
   __asm__("LDA %b", ZP_CNT);
   __asm__("CLC");
   __asm__("ADC #$40");
   __asm__("STA %b", ZP_CNT);
   __asm__("BNE %g", circle); // Time to shift a pixel ?

   // Here is reached 15 times pr. second.

   // Ok, we shift one pixel.
   __asm__("LDA %b", ZP_XSCROLL);
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("AND #$0F");
   __asm__("STA %b", ZP_XSCROLL);
   __asm__("CMP #$0F");
   __asm__("BNE %g", circle); // Time to shift a whole byte ?

   // Ok, we shift a whole byte.
   __asm__("LDA %w", VGA_ADDR_SCREEN+3*40); // Keep left-most character
   __asm__("TAY");

   __asm__("LDA #%b", 3*40);
more_scroll:
   __asm__("TAX");
   __asm__("LDA %w,X", VGA_ADDR_SCREEN+1);
   __asm__("STA %w,X", VGA_ADDR_SCREEN);
   __asm__("TXA");
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("CMP #%b", 4*40U-1);
   __asm__("BNE %g", more_scroll);

   // Wrap around
   __asm__("TYA");
   __asm__("STA %w", VGA_ADDR_SCREEN+4*40-1);


   // Ok, we shift a whole byte.
   __asm__("LDA %w", MEM_COL+3*40); // Keep left-most character
   __asm__("TAY");

   __asm__("LDA #%b", 3*40);
more_scroll2:
   __asm__("TAX");
   __asm__("LDA %w,X", MEM_COL+1);
   __asm__("STA %w,X", MEM_COL);
   __asm__("TXA");
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("CMP #%b", 4*40U-1);
   __asm__("BNE %g", more_scroll2);

   // Wrap around
   __asm__("TYA");
   __asm__("STA %w", MEM_COL+4*40-1);

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

   __asm__("JMP %g", end_irq);

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
   resetColorLine();

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

