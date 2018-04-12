//
// This implements the Tic-Tac-Toe game.
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.

#define COL_LIGHT       0x6F   // 011_011_11
#define COL_DARK        0x44   // 010_001_00
#define COL_BLACK       0x00   // 000_000_00

// Variables
static char pieces[9];
static int gameOver;

// Constants
static const char * const strings[16] = {
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

static void __fastcall__ my_memcpy(void)
{
loop:
   __asm__("DEY");
   __asm__("LDA (%b),Y", ZP_SRC_LO);
   __asm__("STA (%b),Y", ZP_DST_LO);
   __asm__("TYA");
   __asm__("BNE %g", loop);
} // end of copyLine

static void __fastcall__ initScreen(void)
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

// Draw an 'X' at the desired position
static void __fastcall__ drawX(void)
{
   // Find address of position on screen
   __asm__("CLC");
   __asm__("ROL A");  // Multiply by 2
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

} // end of drawX

// Draw an 'O' at the desired position
static void __fastcall__ drawO(void)
{
   // Find address of position on screen
   __asm__("CLC");
   __asm__("ROL A");  // Multiply by 2
   __asm__("TAX");
   __asm__("LDA %v,X", squares);
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("INX");
   __asm__("LDA %v,X", squares);
   __asm__("STA %b", ZP_SCREEN_POS_HI);

   // Place "O" at the position
   __asm__("LDA #$01");
   __asm__("TAY");
   __asm__("LDA #%b", 'O');
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);
   __asm__("INY");
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);

   __asm__("LDA #$28");
   __asm__("TAY");
   __asm__("LDA #%b", 'O');
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);
   __asm__("INY");
   __asm__("INY");
   __asm__("INY");
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);

   __asm__("LDA #$50");
   __asm__("TAY");
   __asm__("LDA #%b", 'O');
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);
   __asm__("INY");
   __asm__("INY");
   __asm__("INY");
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);

   __asm__("LDA #$79");
   __asm__("TAY");
   __asm__("LDA #%b", 'O');
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);
   __asm__("INY");
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO);

} // end of drawO

// Resets game to start
static void __fastcall__ newGame(void)
{
   __asm__("LDX #$00");

loop:
   __asm__("LDA #$00");
   __asm__("STA %v,X", pieces);
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP #$09");
   __asm__("BNE %g", loop);

   __asm__("LDA #$00");
   __asm__("STA %v", gameOver);
} // end of newGame

// Figure out where to place the next piece
static void __fastcall__ findO(void)
{
   __asm__("LDX #$00");

loop:
   __asm__("LDA %v,X", pieces);
   __asm__("BEQ %g", exit);
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP #$09");
   __asm__("BNE %g", loop);

exit:
   __asm__("TXA");
} // end of findO

// Checks if player in 'A' has won the game.
void __fastcall__ checkEnd(void)
{
   __asm__("LDX #$00");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow1);
   __asm__("LDX #$01");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow1);
   __asm__("LDX #$02");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow1);
   __asm__("RTS");   // Player 'A' has won.
nextRow1:

   __asm__("LDX #$03");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow2);
   __asm__("LDX #$04");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow2);
   __asm__("LDX #$05");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow2);
   __asm__("RTS");   // Player 'A' has won.
nextRow2:

   __asm__("LDX #$06");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow3);
   __asm__("LDX #$07");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow3);
   __asm__("LDX #$08");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow3);
   __asm__("RTS");   // Player 'A' has won.
nextRow3:

   __asm__("LDX #$00");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow4);
   __asm__("LDX #$03");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow4);
   __asm__("LDX #$06");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow4);
   __asm__("RTS");   // Player 'A' has won.
nextRow4:

   __asm__("LDX #$01");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow5);
   __asm__("LDX #$04");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow5);
   __asm__("LDX #$07");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow5);
   __asm__("RTS");   // Player 'A' has won.
nextRow5:

   __asm__("LDX #$02");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow6);
   __asm__("LDX #$05");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow6);
   __asm__("LDX #$08");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow6);
   __asm__("RTS");   // Player 'A' has won.
nextRow6:

   __asm__("LDX #$02");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow7);
   __asm__("LDX #$04");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow7);
   __asm__("LDX #$06");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow7);
   __asm__("RTS");   // Player 'A' has won.
nextRow7:

   __asm__("LDX #$00");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow8);
   __asm__("LDX #$04");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow8);
   __asm__("LDX #$08");
   __asm__("CMP %v,X", pieces);
   __asm__("BNE %g", nextRow8);
   __asm__("RTS");   // Player 'A' has won.
nextRow8:

   __asm__("LDA #$00"); // Return zero => game not finished.

} // end of checkEnd

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

new:
   clearScreen();
   initScreen();
   newGame();

loop:
   // This is a blocking call; it won't return until a valid keypress is detected.
   readFromKeyboard();

   // Check if a new game is requested
   __asm__("CMP #%b", 'N');
   __asm__("BEQ %g", new);

   // If game over, no more pieces may be placed.
   __asm__("TAX");
   __asm__("LDA %v", gameOver);
   __asm__("BNE %g", new);
   __asm__("TXA");

   // Check if a digit was pressed
   __asm__("CMP #$30");
   __asm__("BCC %g", loop);
   __asm__("CMP #$3A");
   __asm__("BCS %g", loop);

   // Convert into range 0-8
   __asm__("SEC");
   __asm__("SBC #$31");

   // Check whether square is already occupied
   __asm__("TAX");
   __asm__("LDA %v,X", pieces);
   __asm__("BNE %g", loop);

   // Place new piece in square
   __asm__("LDA #%b", 'X');
   __asm__("STA %v,X", pieces);
   __asm__("TXA");
   drawX();

   __asm__("LDA #%b", 'X');
   checkEnd();
   __asm__("STA %v", gameOver);
   __asm__("BNE %g", loop);

   findO();

   __asm__("TAX");
   __asm__("LDA #%b", 'O');
   __asm__("STA %v,X", pieces);
   __asm__("TXA");
   drawO();

   __asm__("LDA #%b", 'O');
   checkEnd();
   __asm__("STA %v", gameOver);
   __asm__("BNE %g", loop);

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

