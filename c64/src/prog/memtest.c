#include "memorymap.h"

//#define MEM_RAM  0x0000 // - 0x07FF
//#define MEM_DISP 0x8000 // - 0x83FF
//#define MEM_COL  0x8800 // - 0x8BFF
//#define MEM_MOB  0x8400 // - 0x847F
//#define MEM_CONF 0x8600 // - 0x861F
//#define MEM_FONT 0x9000 // - 0x9FFF
//#define MEM_ROM  0xF800 // - 0xFFFF

void __fastcall__ reset(void)
{
   __asm__("LDA #$11");
   __asm__("STA %w", MEM_RAM);
   __asm__("LDA #$22");
   __asm__("STA %w", MEM_DISP);
   __asm__("LDA #$33");
   __asm__("STA %w", MEM_MOB);
   __asm__("LDA #$44");
   __asm__("STA %w", MEM_CONF);
   __asm__("LDA #$55");
   __asm__("STA %w", MEM_FONT);
   __asm__("LDA #$66");
   __asm__("STA %w", MEM_ROM);
   __asm__("LDA #$77");
   __asm__("STA %w", MEM_COL);

   __asm__("LDA %w", MEM_RAM);
   __asm__("CMP #$11");
   __asm__("BNE %g", error); 
   __asm__("LDA %w", MEM_DISP);
   __asm__("CMP #$22");
   __asm__("BNE %g", error); 
   __asm__("LDA %w", MEM_MOB);
   __asm__("CMP #$33");
   __asm__("BNE %g", error); 
   __asm__("LDA %w", MEM_CONF);
   __asm__("CMP #$44");
   __asm__("BNE %g", error); 
   __asm__("LDA %w", MEM_FONT);
   __asm__("CMP #$55");
   __asm__("BNE %g", error); 
   __asm__("LDA %w", MEM_ROM);
   __asm__("CMP #$66");
   __asm__("BNE %g", error); 
   __asm__("LDA %w", MEM_COL);
   __asm__("CMP #$77");
   __asm__("BNE %g", error); 
noError:
   __asm__("JMP %g", noError); 

error:
   __asm__("JMP %g", error); 
} // end of reset

// The interrupt service routine.
void __fastcall__ irq(void)
{
   __asm__("RTI");
} // end of irq

// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

