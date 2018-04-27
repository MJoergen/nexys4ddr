//
// This solves the 8-queens problem.
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "keyboard.h"

#define COL_WHITE       0xFFU   // 111_111_11
#define COL_LIGHT       0x6FU   // 011_011_11
#define COL_DARK        0x44U   // 010_001_00
#define COL_BLACK       0x00U   // 000_000_00
#define COL_RED         0xE0U   // 111_000_00

#define HELP_POS_X      3
#define HELP_POS_Y      11

#define KEY_STEP        0x1B   // 's'
#define KEY_MODE        0x3A   // 'm'

// Constants
static const char strHelp1[] = "Press S to step.";
static const char strHelp2[] = "Press M to change step mode.";
static const char strMode[]  = "Current step mode is: ";
static const char * const strModes[] = {
   "Single.  ",
   "Solution.",
   "All.     ",
   "Loop.    "};

// Variables

static char positions[8];
static char curIndex;
static char curLine;

static char countLo;
static char countHi;
static char solutions;
static char stepMode;
#define STEP_MODE_SINGLE   0
#define STEP_MODE_SOLUTION 1
#define STEP_MODE_ALL      2
#define STEP_MODE_LOOP     3

static char irqA;
static char irqX;
static char lastKey; 

static char tempLo;
static char tempHi;
static char temp;

static void __fastcall__ my_memcpy(void)
{
loop:
   __asm__("DEY");
   __asm__("LDA (%b),Y", ZP_SRC_LO);
   __asm__("STA (%b),Y", ZP_DST_LO);
   __asm__("TYA");
   __asm__("BNE %g", loop);
} // end of my_memcpy

static void __fastcall__ printHelp(void)
{
   __asm__("LDA #<%v", strHelp1);
   __asm__("STA %w", ZP_SRC_LO);
   __asm__("LDA #>%v", strHelp1);
   __asm__("STA %w", ZP_SRC_HI);
   __asm__("LDA #<%w", MEM_DISP + HELP_POS_Y*40 + HELP_POS_X);
   __asm__("STA %w", ZP_DST_LO);
   __asm__("LDA #>%w", MEM_DISP + HELP_POS_Y*40 + HELP_POS_X);
   __asm__("STA %w", ZP_DST_HI);
   __asm__("LDA #%b", sizeof(strHelp1)-1);
   __asm__("TAY");
   my_memcpy();

   __asm__("LDA #<%v", strHelp2);
   __asm__("STA %w", ZP_SRC_LO);
   __asm__("LDA #>%v", strHelp2);
   __asm__("STA %w", ZP_SRC_HI);
   __asm__("LDA #<%w", MEM_DISP + (HELP_POS_Y+1)*40 + HELP_POS_X);
   __asm__("STA %w", ZP_DST_LO);
   __asm__("LDA #>%w", MEM_DISP + (HELP_POS_Y+1)*40 + HELP_POS_X);
   __asm__("STA %w", ZP_DST_HI);
   __asm__("LDA #%b", sizeof(strHelp2)-1);
   __asm__("TAY");
   my_memcpy();

} // end of printHelp

static void __fastcall__ printStepMode(void)
{
   __asm__("LDA #<%v", strMode);
   __asm__("STA %w", ZP_SRC_LO);
   __asm__("LDA #>%v", strMode);
   __asm__("STA %w", ZP_SRC_HI);
   __asm__("LDA #<%w", MEM_DISP + (HELP_POS_Y+2)*40 + HELP_POS_X);
   __asm__("STA %w", ZP_DST_LO);
   __asm__("LDA #>%w", MEM_DISP + (HELP_POS_Y+2)*40 + HELP_POS_X);
   __asm__("STA %w", ZP_DST_HI);
   __asm__("LDA #%b", sizeof(strMode)-1);
   __asm__("TAY");
   my_memcpy();

   __asm__("LDA %v", stepMode);
   __asm__("CLC");
   __asm__("ROL A");
   __asm__("TAX");
   __asm__("LDA %v,X", strModes);
   __asm__("STA %w", ZP_SRC_LO);
   __asm__("INX");
   __asm__("LDA %v,X", strModes);
   __asm__("STA %w", ZP_SRC_HI);
   __asm__("LDA #<%w", MEM_DISP + (HELP_POS_Y+2)*40 + HELP_POS_X + sizeof(strMode)-1);
   __asm__("STA %w", ZP_DST_LO);
   __asm__("LDA #>%w", MEM_DISP + (HELP_POS_Y+2)*40 + HELP_POS_X + sizeof(strMode)-1);
   __asm__("STA %w", ZP_DST_HI);
   __asm__("LDA #%b", 9);
   __asm__("TAY");
   my_memcpy();
} // end of printStepMode

static void __fastcall__ clearScreen(void)
{
   // Clear the screen
   __asm__("LDA #<%w", MEM_DISP); 
   __asm__("STA %b", ZP_DST_LO); 
   __asm__("LDA #>%w", MEM_DISP); 
   __asm__("STA %b", ZP_DST_HI); 
   __asm__("LDA #$00"); 
   __asm__("TAY"); 
clear2:
   __asm__("LDA #$20"); 
clear1:
   __asm__("STA (%b),Y", ZP_DST_LO); 
   __asm__("INY"); 
   __asm__("BNE %g", clear1); 
   __asm__("LDA %b", ZP_DST_HI); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %b", ZP_DST_HI); 
   __asm__("CMP #>%w", MEM_DISP+4*256); 
   __asm__("BNE %g", clear2); 
} // end of clearScreen

static void __fastcall__ clearColours(void)
{
   // Clear the screen
   __asm__("LDA #<%w", MEM_COL); 
   __asm__("STA %b", ZP_DST_LO); 
   __asm__("LDA #>%w", MEM_COL); 
   __asm__("STA %b", ZP_DST_HI); 
   __asm__("LDA #$00"); 
   __asm__("TAY"); 
clear2:
   __asm__("LDA #%b", COL_WHITE); 
clear1:
   __asm__("STA (%b),Y", ZP_DST_LO); 
   __asm__("INY"); 
   __asm__("BNE %g", clear1); 
   __asm__("LDA %b", ZP_DST_HI); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %b", ZP_DST_HI); 
   __asm__("CMP #>%w", MEM_COL+4*256); 
   __asm__("BNE %g", clear2); 
} // end of clearColours

static void printBoard()
{
   __asm__("LDA #$00"); 
   __asm__("STA %v", curLine); 
   __asm__("LDA #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA #$80"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 

loop:
   __asm__("LDA #$07"); 
   __asm__("TAY"); 
   __asm__("LDA #%b", '.'); 
loop2:
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("DEY"); 
   __asm__("BPL %g", loop2); 

   __asm__("LDA %v", curLine); 
   __asm__("CMP %v", curIndex); 
   __asm__("BEQ %g", thisRow); 
   __asm__("TAX"); 
   __asm__("LDA %v,X", positions); 
   __asm__("TAY"); 
   __asm__("LDA #%b", 'o'); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("JMP %g", nextRow); 

thisRow:
   __asm__("TAX"); 
   __asm__("LDA %v,X", positions); 
   __asm__("TAY"); 
   __asm__("LDA #%b", 'O'); 
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 

nextRow:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 

   __asm__("LDA %v", curLine); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %v", curLine); 
   __asm__("CMP #$08"); 
   __asm__("BNE %g", loop); 

} // end of printBoard

static void printIllegal()
{
   __asm__("LDA %v", curIndex);
   __asm__("CMP #$08");
   __asm__("BNE %g", cont);
   __asm__("RTS");

cont:
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
   __asm__("TAY");
checkLegal:
   __asm__("DEX");
   __asm__("BMI %g", checkDiagonal);
   __asm__("CMP %v,X", positions);
   __asm__("BNE %g", checkLegal);
   // Illegal vertical. Register 'X' contains the top row, register 'Y' contains the column.
   __asm__("LDA #<%w", MEM_COL); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA #>%w", MEM_COL); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("STX %v", temp);
   __asm__("TXA");
   __asm__("BEQ %g", draw);
nextRow:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("DEX");
   __asm__("BNE %g", nextRow);
draw:
   __asm__("LDA %v", temp);
   __asm__("TAX");
colRow:
   __asm__("LDA #%b", COL_RED);
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP %v", curIndex);
   __asm__("BCC %g", colRow);
   __asm__("BEQ %g", colRow);

checkDiagonal:
   __asm__("LDA %v", curIndex);
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
checkLegal2:
   __asm__("DEX");
   __asm__("BMI %g", checkDiagonal2);
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("CMP %v,X", positions);
   __asm__("BNE %g", checkLegal2);
   __asm__("TAY");
   // Illegal Diagonal. Register 'X' contains the top row, register 'Y' contains the top column.
   __asm__("LDA #<%w", MEM_COL); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA #>%w", MEM_COL); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("STX %v", temp);
   __asm__("TXA");
   __asm__("BEQ %g", draw2);
nextRow2:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("DEX");
   __asm__("BNE %g", nextRow2);
draw2:
   __asm__("LDA %v", temp);
   __asm__("TAX");
colRow2:
   __asm__("LDA #%b", COL_RED);
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("INX");
   __asm__("INY");
   __asm__("TXA");
   __asm__("CMP %v", curIndex);
   __asm__("BCC %g", colRow2);
   __asm__("BEQ %g", colRow2);

checkDiagonal2:
   __asm__("LDA %v", curIndex);
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
checkLegal3:
   __asm__("DEX");
   __asm__("BMI %g", end);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("CMP %v,X", positions);
   __asm__("BNE %g", checkLegal3);
   __asm__("TAY");
   // Illegal Diagonal. Register 'X' contains the top row, register 'Y' contains the top column.
   __asm__("LDA #<%w", MEM_COL); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA #>%w", MEM_COL); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("STX %v", temp);
   __asm__("TXA");
   __asm__("BEQ %g", draw3);
nextRow3:
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("DEX");
   __asm__("BNE %g", nextRow3);
draw3:
   __asm__("LDA %v", temp);
   __asm__("TAX");
colRow3:
   __asm__("LDA #%b", COL_RED);
   __asm__("STA (%b),Y", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_LO); 
   __asm__("CLC"); 
   __asm__("ADC #$28"); 
   __asm__("STA %b", ZP_SCREEN_POS_LO); 
   __asm__("LDA %b", ZP_SCREEN_POS_HI); 
   __asm__("ADC #$00"); 
   __asm__("STA %b", ZP_SCREEN_POS_HI); 
   __asm__("INX");
   __asm__("DEY");
   __asm__("TXA");
   __asm__("CMP %v", curIndex);
   __asm__("BCC %g", colRow3);
   __asm__("BEQ %g", colRow3);

end:
   __asm__("RTS");
} // end of printIllegal

// Prints a value in register 'A' as a three-digit decimal number
static void printOneByteDec()
{
   __asm__("LDX #$30"); 
doHundreds:
   __asm__("CMP #100"); 
   __asm__("BCC %g", storeHundreds); 
   __asm__("SBC #100"); 
   __asm__("INX"); 
   __asm__("JMP %g", doHundreds); 
storeHundreds:
   __asm__("STX %w", MEM_DISP+12); 

   __asm__("LDX #$30"); 
doTens:
   __asm__("CMP #10"); 
   __asm__("BCC %g", storeTens); 
   __asm__("SBC #10"); 
   __asm__("INX"); 
   __asm__("JMP %g", doTens); 
storeTens:
   __asm__("STX %w", MEM_DISP+13); 

   __asm__("CLC"); 
   __asm__("ADC #$30"); 
   __asm__("STA %w", MEM_DISP+14); 

} // end of printOneByteDec

// Prints a two-byte value (MSB in register 'X' and LSB in register 'A') as a five-digit decimal number
static void printTwoByteDec()
{
   __asm__("STA %v", tempLo); 
   __asm__("STX %v", tempHi); 

   __asm__("LDX #$30"); 
doTenThousands:
   __asm__("LDA %v", tempLo); 
   __asm__("SEC"); 
   __asm__("SBC #<%w", 10000); 
   __asm__("STA %v", tempLo); 
   __asm__("LDA %v", tempHi); 
   __asm__("SBC #>%w", 10000); 
   __asm__("STA %v", tempHi); 
   __asm__("INX"); 
   __asm__("BCS %g", doTenThousands); 
   __asm__("DEX"); 
   __asm__("STX %w", MEM_DISP+50); 
   __asm__("LDA %v", tempLo); 
   __asm__("CLC"); 
   __asm__("ADC #<%w", 10000); 
   __asm__("STA %v", tempLo); 
   __asm__("LDA %v", tempHi); 
   __asm__("ADC #>%w", 10000); 
   __asm__("STA %v", tempHi); 

   __asm__("LDX #$30"); 
doThousands:
   __asm__("LDA %v", tempLo); 
   __asm__("SEC"); 
   __asm__("SBC #<%w", 1000); 
   __asm__("STA %v", tempLo); 
   __asm__("LDA %v", tempHi); 
   __asm__("SBC #>%w", 1000); 
   __asm__("STA %v", tempHi); 
   __asm__("INX"); 
   __asm__("BCS %g", doThousands); 
   __asm__("DEX"); 
   __asm__("STX %w", MEM_DISP+51); 
   __asm__("LDA %v", tempLo); 
   __asm__("CLC"); 
   __asm__("ADC #<%w", 1000); 
   __asm__("STA %v", tempLo); 
   __asm__("LDA %v", tempHi); 
   __asm__("ADC #>%w", 1000); 
   __asm__("STA %v", tempHi); 

   __asm__("LDX #$30"); 
doHundreds:
   __asm__("LDA %v", tempLo); 
   __asm__("SEC"); 
   __asm__("SBC #<%w", 100); 
   __asm__("STA %v", tempLo); 
   __asm__("LDA %v", tempHi); 
   __asm__("SBC #>%w", 100); 
   __asm__("STA %v", tempHi); 
   __asm__("INX"); 
   __asm__("BCS %g", doHundreds); 
   __asm__("DEX"); 
   __asm__("STX %w", MEM_DISP+52); 
   __asm__("LDA %v", tempLo); 
   __asm__("CLC"); 
   __asm__("ADC #<%w", 100); 
   __asm__("STA %v", tempLo); 
   __asm__("LDA %v", tempHi); 
   __asm__("ADC #>%w", 100); 
   __asm__("STA %v", tempHi); 

   // At this point, tempHi is zero.
   __asm__("LDA %v", tempLo); 
   __asm__("LDX #$30"); 
doTens:
   __asm__("CMP #10"); 
   __asm__("BCC %g", storeTens); 
   __asm__("SBC #10"); 
   __asm__("INX"); 
   __asm__("JMP %g", doTens); 
storeTens:
   __asm__("STX %w", MEM_DISP+53); 

   __asm__("CLC"); 
   __asm__("ADC #$30"); 
   __asm__("STA %w", MEM_DISP+54); 

} // end of printTwoByteDec

static void updateBoard()
{
   // Is it legal
   __asm__("LDA %v", curIndex);
   __asm__("CMP #$08");
   __asm__("BNE %g", checkVertical);
   __asm__("LDA #$07");
   __asm__("STA %v", curIndex);
   __asm__("JMP %g", next);

checkVertical:
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
checkLegal:
   __asm__("DEX");
   __asm__("BMI %g", checkDiagonal);
   __asm__("CMP %v,X", positions);
   __asm__("BEQ %g", next);
   __asm__("JMP %g", checkLegal);

checkDiagonal:
   __asm__("LDA %v", curIndex);
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
checkLegal2:
   __asm__("DEX");
   __asm__("BMI %g", checkDiagonal2);
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("CMP %v,X", positions);
   __asm__("BEQ %g", next);
   __asm__("JMP %g", checkLegal2);

checkDiagonal2:
   __asm__("LDA %v", curIndex);
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
checkLegal3:
   __asm__("DEX");
   __asm__("BMI %g", legal);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("CMP %v,X", positions);
   __asm__("BEQ %g", next);
   __asm__("JMP %g", checkLegal3);

goBack:
   __asm__("LDA #$00");
   __asm__("STA %v,X", positions);
   __asm__("LDA %v", curIndex);
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("STA %v", curIndex);
   __asm__("BPL %g", next);

   __asm__("LDA %v", stepMode);
   __asm__("CMP #%b", STEP_MODE_ALL);
   __asm__("BEQ %g", stop);

   __asm__("LDA #$00");
   __asm__("STA %v", curIndex);
   __asm__("RTS");

legal:
   __asm__("LDA %v", curIndex);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %v", curIndex);
   __asm__("CMP #$08");
   __asm__("BEQ %g", found);
   __asm__("JMP %g", finished);

next:
   // Increment current row
   __asm__("LDA %v", curIndex);
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %v,X", positions);

   // Is it overflowed
   __asm__("CMP #$08");
   __asm__("BEQ %g", goBack);

finished:
   __asm__("LDA %v", stepMode);
   __asm__("CMP #%b", STEP_MODE_SINGLE);
   __asm__("BEQ %g", stop);
   __asm__("RTS");

stop:
   // Stop the search, by preventing any further IRQ
   __asm__("LDA #$00"); 
   __asm__("STA %w", VGA_ADDR_MASK);
   __asm__("RTS");

found:
   __asm__("LDA %v", solutions); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %v", solutions); 
   printOneByteDec();

   __asm__("LDA %v", stepMode);
   __asm__("CMP #%b", STEP_MODE_SOLUTION);
   __asm__("BEQ %g", stop);

   __asm__("RTS");
} // end of updateBoard

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

   // Clear the board
   __asm__("LDA #$00");
   __asm__("LDX #$07");
loop1:
   __asm__("STA %v,X", positions);
   __asm__("DEX");
   __asm__("BPL %g", loop1);
   __asm__("LDA #$00");
   __asm__("STA %v", curIndex);
   __asm__("STA %v", countLo);
   __asm__("STA %v", countHi);
   __asm__("STA %v", solutions);
   __asm__("LDA #%b", STEP_MODE_SINGLE);
   __asm__("STA %v", stepMode);

   clearScreen();
   clearColours();
   printHelp();
   printStepMode();
   printBoard();

   __asm__("LDA %v", solutions); 
   printOneByteDec();

   __asm__("LDA %v", countHi); 
   __asm__("TAX"); 
   __asm__("LDA %v", countLo); 
   printTwoByteDec();

   // Configure VGA interrupt
   __asm__("LDA #$E0"); 
   __asm__("STA %w", VGA_ADDR_YLINE);             // Set the interrupt at the end of the screen
   __asm__("LDA %w", VGA_ADDR_IRQ);
   __asm__("STA %w", VGA_ADDR_IRQ);               // Clear any pending IRQ
   __asm__("CLI"); 

   // Any key-press will re-enable interrupt.
loop:
   readCurrentKey();
   __asm__("BEQ %g", halt2); 

   __asm__("CMP %v", lastKey); 
   __asm__("BEQ %g", loop); 
   __asm__("STA %v", lastKey); 

   __asm__("CMP #%b", KEY_STEP); 
   __asm__("BEQ %g", step); 
   __asm__("CMP #%b", KEY_MODE); 
   __asm__("BNE %g", loop); 

   // Change the stepping mode
   __asm__("LDA %v", stepMode);
   __asm__("CLC");
   __asm__("ADC #$01"); 
   __asm__("AND #$03"); 
   __asm__("STA %v", stepMode);
   printStepMode();
   __asm__("JMP %g", loop); 

step:
   __asm__("LDA #$01"); 
   __asm__("STA %w", VGA_ADDR_MASK);
   __asm__("JMP %g", loop); 
halt2:
   __asm__("STA %v", lastKey); 
   __asm__("JMP %g", loop); 

} // end of reset

#define KEY_STEP        0x1B   // 's'
#define KEY_MODE        0x3A   // 'm'

// Maskable interrupt
void __fastcall__ irq(void)
{
   __asm__("STA %v", irqA);                        // Store register A
   __asm__("TXA");
   __asm__("STA %v", irqX);                        // Store register X

   __asm__("LDA %w", VGA_ADDR_IRQ);
   __asm__("STA %w", VGA_ADDR_IRQ);                // Clear any pending IRQ

   updateBoard();
   printBoard();
   clearColours();
   printIllegal();

   __asm__("LDA %v", countLo); 
   __asm__("CLC"); 
   __asm__("ADC #$01"); 
   __asm__("STA %v", countLo); 
   __asm__("LDA %v", countHi); 
   __asm__("ADC #$00"); 
   __asm__("STA %v", countHi); 

   __asm__("LDA %v", countHi); 
   __asm__("TAX"); 
   __asm__("LDA %v", countLo); 
   printTwoByteDec();

   __asm__("LDA %v", irqX);                        // Restore register X
   __asm__("TAX");
   __asm__("LDA %v", irqA);                        // Restore register A
   __asm__("RTI");
} // end of irq

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

