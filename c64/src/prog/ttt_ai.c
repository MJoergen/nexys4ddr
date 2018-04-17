#include "zeropage.h"
#include "ttt_vga.h"

static char best[128];
static char positions[5];
static char num_pos;

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
   __asm__("STA %v", num_pos);
} // end of ai_newgame

// Figure out where to place the next piece
void __fastcall__ ai_findO(void)
{
   // First compute the index

   __asm__("LDA #$00");
   __asm__("STA %b", ZP_AI);
   __asm__("LDX #$00");
loop:
   __asm__("LDA %v,X", pieces);
   __asm__("CLC");
   __asm__("ADC %b", ZP_AI);
   __asm__("ROL A");
   __asm__("STA %b", ZP_AI);
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP #$09");
   __asm__("BNE %g", loop);

   // Next look up the move
   __asm__("LDA %b", ZP_AI);
   __asm__("TAX");
   __asm__("LDA %v,X", best);
   __asm__("TAX");

   // Check if move is valid
   __asm__("LDA #$09");
   __asm__("TAY");
next:
   __asm__("DEY");
   __asm__("BEQ %g", end);
   __asm__("LDA %v,X", pieces);
   __asm__("BEQ %g", valid);
   __asm__("INX");
   __asm__("TXA");
   __asm__("CMP #$09");
   __asm__("BCS %g", next);
   __asm__("LDX #$00");
   __asm__("JMP %g", next);

valid:
   __asm__("TXA");
   __asm__("TAY");
   __asm__("LDA %v", num_pos);
   __asm__("TAX");
   __asm__("STA %v,X", positions);
   __asm__("INX");
   __asm__("TXA");
   __asm__("STA %v", num_pos);

   __asm__("TYA");
   __asm__("RTS");

end:
   __asm__("LDA #$09");
   __asm__("RTS");

} // end of ai_findO

void __fastcall__ ai_update(void)
{
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_AI);
   __asm__("CMP %v", num_pos);
   __asm__("BEQ %g", end);

loop:
   __asm__("TAX");
   __asm__("LDA %v,X", positions);
   __asm__("TAX");
   __asm__("LDA %v,X", best);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %v,X", best);

   __asm__("LDA %b", ZP_AI);
   __asm__("CLC");
   __asm__("ADC #$01");
   __asm__("STA %b", ZP_AI);
   __asm__("CMP %v", num_pos);
   __asm__("BNE %g", loop);

end:
   __asm__("RTS");
} // end of ai_update

