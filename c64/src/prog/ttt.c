//
// This implements the Tic-Tac-Toe game.
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.

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

void __fastcall__ my_memcpy(void)
{
loop:
   __asm__("DEY"); 
   __asm__("LDA (%b),Y", ZP_SRC_LO); 
   __asm__("STA (%b),Y", ZP_DST_LO); 
   __asm__("TYA"); 
   __asm__("BNE %g", loop); 
} // end of copyLine

static const char *strings[16] = {
   "+----+----+----+",
   "|    |    |    |",
   "| 11 | 22 | 33 |",
   "| 11 | 22 | 33 |",
   "|    |    |    |",
   "+----+----+----+",
   "|    |    |    |",
   "| 44 | 55 | 66 |",
   "| 44 | 55 | 66 |",
   "|    |    |    |",
   "+----+----+----+",
   "|    |    |    |",
   "| 77 | 88 | 99 |",
   "| 77 | 88 | 99 |",
   "|    |    |    |",
   "+----+----+----+"};

void __fastcall__ initScreen(void)
{
   __asm__("LDA #$00"); 
   __asm__("STA %b", ZP_DST_LO); 
   __asm__("LDA #$80"); 
   __asm__("STA %b", ZP_DST_HI); 

   __asm__("LDA #$00"); 
   __asm__("TAX"); 

loop:
   __asm__("LDA %v,X", strings); 
   __asm__("STA %b", ZP_SRC_LO); 
   __asm__("INX"); 
   __asm__("LDA %v,X", strings); 
   __asm__("STA %b", ZP_SRC_HI); 
   __asm__("INX"); 

   __asm__("LDA #$10"); 
   __asm__("TAY"); 

   my_memcpy();

   __asm__("LDA %b", ZP_DST_LO);
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA %b", ZP_DST_HI);
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_DST_HI);

   __asm__("TXA"); 
   __asm__("CMP #$20"); 
   __asm__("BNE %g", loop); 

} // end of initScreen

static const short squares[9] = {
   MEM_DISP +  1*40 +  1,
   MEM_DISP +  1*40 +  6,
   MEM_DISP +  1*40 + 11,
   MEM_DISP +  6*40 +  1,
   MEM_DISP +  6*40 +  6,
   MEM_DISP +  6*40 + 11,
   MEM_DISP + 11*40 +  1,
   MEM_DISP + 11*40 +  6,
   MEM_DISP + 11*40 + 11};

// Entry point after CPU reset
void __fastcall__ reset(void)
{
   __asm__("SEI");                           // Disable all interrupts
   __asm__("LDX #$FF");
   __asm__("TXS");                           // Reset stack pointer

   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);
   
   clearScreen();
   initScreen();

loop:
   __asm__("JSR %v", readFromKeyboard);      // This is a blocking call; it won't return until a valid keypress is detected.

   // Check if valid key pressed
   __asm__("CMP #$30");
   __asm__("BCC %g", loop);
   __asm__("CMP #$3A");
   __asm__("BCS %g", loop);

   // Convert into range 0-8
   __asm__("SEC");
   __asm__("SBC #$31");

   // Find address of position on screen
   __asm__("TAX"); 
   __asm__("LDA %v,X", squares); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("INX"); 
   __asm__("LDA %v,X", squares); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 

   // Place "X" at the position
   __asm__("LDA #$00"); 
   __asm__("TAY"); 
   __asm__("LDA #%b", 'X'); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("INY"); 
   __asm__("INY"); 
   __asm__("INY"); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 

   __asm__("LDA #$29"); 
   __asm__("TAY"); 
   __asm__("LDA #%b", 'X'); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("INY"); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 

   __asm__("LDA #$51"); 
   __asm__("TAY"); 
   __asm__("LDA #%b", 'X'); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("INY"); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 

   __asm__("LDA #$78"); 
   __asm__("TAY"); 
   __asm__("LDA #%b", 'X'); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("INY"); 
   __asm__("INY"); 
   __asm__("INY"); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 

   goto loop;  // Just do an endless loop.
} // end of reset

// Maskable interrupt
void __fastcall__ irq(void)
{
   // Not used.
   __asm__("RTI");
} // end of irq

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

