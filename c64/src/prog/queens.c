//
// This solves the 8-queens problem.
//

#include "memorymap.h"
#include "zeropage.h"   // Variables to be stored in the zero-page.
#include "keyboard.h"

#define COL_WHITE       0xFF   // 111_111_11
#define COL_LIGHT       0x6F   // 011_011_11
#define COL_DARK        0x44   // 010_001_00
#define COL_BLACK       0x00   // 000_000_00

// Variables

char positions[8];
char curIndex;
char curLine;

char countLow;
char countHigh;
char solutions;

char irqA;
char irqX;
char lastKey; 

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

// Prints a value in register 'A' as a two-digit hex number
static void printHex()
{
   __asm__("ROR A"); 
   __asm__("ROR A"); 
   __asm__("ROR A"); 
   __asm__("ROR A"); 
   __asm__("AND #$0F"); 
   __asm__("CMP #$0A"); 
   __asm__("BCC %g", dig); 
   __asm__("CLC"); 
   __asm__("ADC #$07"); 
dig:
   __asm__("CLC"); 
   __asm__("ADC #$30"); 
   __asm__("STA %w", MEM_DISP+10); 

   __asm__("LDA %v", solutions); 
   __asm__("AND #$0F"); 
   __asm__("CMP #$0A"); 
   __asm__("BCC %g", dig2); 
   __asm__("CLC"); 
   __asm__("ADC #$07"); 
dig2:
   __asm__("CLC"); 
   __asm__("ADC #$30"); 
   __asm__("STA %w", MEM_DISP+11); 
} // end of printHex

// Prints a value in register 'A' as a three-digit decimal number
static void printDec()
{
   __asm__("LDX #$30"); 
doHundreds:
   __asm__("CMP #100"); 
   __asm__("BCC %g", doTens); 
   __asm__("SBC #100"); 
   __asm__("INX"); 
   __asm__("JMP %g", doHundreds); 

doTens:
   __asm__("STA %w", MEM_DISP+10); 

   __asm__("CMP #100"); 
   __asm__("BCS %g", atLeast100); 
   __asm__("ROR A"); 
   __asm__("ROR A"); 
   __asm__("ROR A"); 
   __asm__("ROR A"); 
   __asm__("AND #$0F"); 
   __asm__("CMP #$0A"); 
   __asm__("BCC %g", dig); 
   __asm__("CLC"); 
   __asm__("ADC #$07"); 
dig:
   __asm__("CLC"); 
   __asm__("ADC #$30"); 
   __asm__("STA %w", MEM_DISP+10); 

   __asm__("LDA %v", solutions); 
   __asm__("AND #$0F"); 
   __asm__("CMP #$0A"); 
   __asm__("BCC %g", dig2); 
   __asm__("CLC"); 
   __asm__("ADC #$07"); 
dig2:
   __asm__("CLC"); 
   __asm__("ADC #$30"); 
   __asm__("STA %w", MEM_DISP+11); 
} // end of printDec

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
   __asm__("BMI %g", stop);
   __asm__("JMP %g", next);

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
   printCount();
//   __asm__("JMP %g", stop); 
   __asm__("RTS");
} // end of updateBoard

// Entry point after CPU reset
void __fastcall__ reset(void)
{
   __asm__("SEI");                           // Disable all interrupts
   __asm__("LDX #$FF");
   __asm__("TXS");                           // Reset stack pointer

   clearScreen();

   // Configure text color
   __asm__("LDA #%b", COL_LIGHT);
   __asm__("STA %w",  VGA_ADDR_FGCOL);
   __asm__("LDA #%b", COL_DARK);
   __asm__("STA %w",  VGA_ADDR_BGCOL);

   // Clear the board
   __asm__("LDA #$00");
   __asm__("LDX #$07");
loop:
   __asm__("STA %v,X", positions);
   __asm__("DEX");
   __asm__("BPL %g", loop);
   __asm__("LDA #$00");
   __asm__("STA %v", curIndex);
   __asm__("STA %v", countLow);
   __asm__("STA %v", countHigh);
   __asm__("STA %v", solutions);

   // Configure VGA interrupt
   __asm__("LDA #$E0"); 
   __asm__("STA %w", VGA_ADDR_YLINE);             // Set the interrupt at the end of the screen
   __asm__("LDA #$01"); 
   __asm__("STA %w", VGA_ADDR_MASK);
   __asm__("LDA %w", VGA_ADDR_IRQ);
   __asm__("STA %w", VGA_ADDR_IRQ);               // Clear any pending IRQ
   __asm__("CLI"); 

   // Any key-press will re-enable interrupt.
halt:
   readCurrentKey();
   __asm__("BEQ %g", halt2); 
   __asm__("CMP %v", lastKey); 
   __asm__("BEQ %g", halt); 
   __asm__("STA %v", lastKey); 
   __asm__("LDA #$01"); 
   __asm__("STA %w", VGA_ADDR_MASK);
   __asm__("JMP %g", halt); 
halt2:
   __asm__("STA %v", lastKey); 
   __asm__("JMP %g", halt); 

} // end of reset

// Maskable interrupt
void __fastcall__ irq(void)
{
   __asm__("STA %v", irqA);                        // Store register A
   __asm__("TXA");
   __asm__("STA %v", irqA);                        // Store register X

   __asm__("LDA %w", VGA_ADDR_IRQ);
   __asm__("STA %w", VGA_ADDR_IRQ);                // Clear any pending IRQ

   printBoard();
   updateBoard();

   __asm__("LDA %v", irqA);                        // Restore register X
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

