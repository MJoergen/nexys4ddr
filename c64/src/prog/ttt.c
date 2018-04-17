//
// This implements the Tic-Tac-Toe game.
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "keyboard.h"
#include "ttt_vga.h"
#include "ttt_ai.h"

#define COL_WHITE       0xFF   // 111_111_11
#define COL_LIGHT       0x6E   // 011_011_10
#define COL_DARK        0x24   // 001_001_00
#define COL_BLACK       0x00   // 000_000_00

// Constants
const char win_str[] = "Player . won!";
const char draw_str[] = "Well done!";

// Global variables
char pieces[9];

// Local variables
static int gameOver;

static void __fastcall__ clearScreen(void)
{
   // Clear the screen
   __asm__("LDA #<%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_SCREEN_POS_LO);
   __asm__("LDA #>%w", VGA_ADDR_SCREEN);
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
   __asm__("LDA #<%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #%b", sizeof(win_str));
   __asm__("TAY");
   __asm__("LDA #$20");
   my_memset();
} // end of clearLine

// Resets game to start
static void __fastcall__ newGame(void)
{
   __asm__("LDA #<%v", pieces);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%v", pieces);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #$09");
   __asm__("TAY");
   __asm__("LDA #$00");
   my_memset();

   __asm__("LDA #$00");
   __asm__("STA %v", gameOver);
} // end of newGame

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
   ai_init();

new:
   //clearScreen();
   clearLine();
   vga_init();
   ai_newgame();
   newGame();

loop:
   // This is a blocking call; it won't return until a valid keypress is detected.
   readFromKeyboard();

   // Check if a new game is requested
   __asm__("CMP #%b", 'N');
   __asm__("BEQ %g", new);
   __asm__("CMP #%b", 'n');
   __asm__("BEQ %g", new);

   // If game over, no more pieces may be placed.
   __asm__("TAX");
   __asm__("LDA %v", gameOver);
   __asm__("BNE %g", loop);
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

   __asm__("LDA #%b", 'X');
   checkEnd();
   __asm__("TAX");
   __asm__("STA %v", gameOver);
   __asm__("BNE %g", update);

   ai_findO();
   __asm__("CMP #$09");
   __asm__("BEQ %g", draw);

   __asm__("TAX");
   __asm__("LDA #%b", 'O');
   __asm__("STA %v,X", pieces);
   __asm__("TXA");

   __asm__("LDA #%b", 'O');
   checkEnd();
   __asm__("TAX");
   __asm__("STA %v", gameOver);
   __asm__("BNE %g", writeEnd);

   goto loop;  // Just do an endless loop.

update:
   ai_update();

writeEnd:
   __asm__("LDA #<%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", win_str);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", win_str);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #%b", sizeof(win_str));
   __asm__("TAY");
   my_memcpy();
   __asm__("LDA %v", gameOver);
   __asm__("STA %w", VGA_ADDR_SCREEN + 7);
   __asm__("JMP %g", loop);

draw:
   __asm__("STA %v", gameOver);

   __asm__("LDA #<%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%w", VGA_ADDR_SCREEN);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #<%v", win_str);
   __asm__("STA %b", ZP_SRC_LO);
   __asm__("LDA #>%v", win_str);
   __asm__("STA %b", ZP_SRC_HI);
   __asm__("LDA #%b", sizeof(draw_str));
   __asm__("TAY");
   my_memcpy();

   goto loop;  // Just do an endless loop.
 
} // end of reset

// Maskable interrupt
void __fastcall__ irq(void)
{
   vga_irq();
   // Not used.
   __asm__("RTI");
} // end of irq

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

