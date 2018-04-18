#include "zeropage.h"
#include "ttt_vga.h"
#include "memorymap.h"

static char best[256];
static char positions[5];

// External declaration
extern char pieces[9];

void __fastcall__ ai_init(void)
{
   __asm__("LDX #$00");
   __asm__("LDA #$11");
   __asm__("TAY");

loop:
   __asm__("TYA");
   __asm__("ROL A");
   __asm__("ADC #$AB");
   __asm__("TAY");
   __asm__("AND #$0F");
   __asm__("CMP #$09");
   __asm__("BCS %g", loop);

   __asm__("STA %v,X", best);
   __asm__("INX");
   __asm__("BNE %g", loop);
} // end of ai_init

void __fastcall__ ai_newgame(void)
{
   __asm__("LDA #<%v", positions);
   __asm__("STA %b", ZP_DST_LO);
   __asm__("LDA #>%v", positions);
   __asm__("STA %b", ZP_DST_HI);
   __asm__("LDA #%b", sizeof(positions));
   __asm__("TAY");
   __asm__("LDA #$00");
   my_memset();

   __asm__("LDA #$00");
   __asm__("STA %b", ZP_AI_NUMPOS);
} // end of ai_newgame

// Figure out where to place the next piece
void __fastcall__ ai_findO(void)
{
   // First compute the index

   __asm__("LDA #$00");
   __asm__("STA %b", ZP_AI_TEMP);
   __asm__("LDX #$00");
loop:
   __asm__("LDA %v,X", pieces);
   __asm__("CLC");
   __asm__("ADC %b", ZP_AI_TEMP);
   __asm__("ROL A");
   __asm__("STA %b", ZP_AI_TEMP);
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP #$09");
   __asm__("BNE %g", loop);

   // Next look up the move
   __asm__("LDA %b", ZP_AI_TEMP);
   __asm__("TAX");
   __asm__("LDA %v,X", best);
   __asm__("TAX");

   // Check if move in 'X' is valid
   __asm__("LDA #$09");
   __asm__("TAY");
next:
   __asm__("DEY");
   __asm__("BMI %g", end);
   __asm__("LDA %v,X", pieces);
   __asm__("BEQ %g", valid);
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP #$09");
   __asm__("BCC %g", next);
   __asm__("LDX #$00");
   __asm__("JMP %g", next);

valid:
   // Move 'X' to 'Y'
   __asm__("TXA");
   __asm__("TAY");

   // Store current position
   __asm__("LDA %b", ZP_AI_NUMPOS);
   __asm__("TAX");
   __asm__("LDA %b", ZP_AI_TEMP);
   __asm__("STA %v,X", positions);
   __asm__("INX");
   __asm__("TXA");
   __asm__("STA %b", ZP_AI_NUMPOS);

   // Return chosen move in 'A'
   __asm__("TYA");
   __asm__("RTS");

end:
   __asm__("LDA #$09");
   __asm__("RTS");
} // end of ai_findO

// Increment best moves for each position visited in this game
void __fastcall__ ai_update(void)
{
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_AI_TEMP); // Index into positions[]
   __asm__("CMP %b", ZP_AI_NUMPOS);
   __asm__("BEQ %g", end);

loop:
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
   __asm__("TAX");
   __asm__("LDA %v,X", best);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %v,X", best);

   __asm__("CMP #$09");
   __asm__("BCC %g", next);
   __asm__("LDA #$00");
   __asm__("STA %v,X", best);

next:
   __asm__("LDA %b", ZP_AI_TEMP);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %b", ZP_AI_TEMP);
   __asm__("CMP %b", ZP_AI_NUMPOS);
   __asm__("BNE %g", loop);

end:
   __asm__("RTS");
} // end of ai_update

