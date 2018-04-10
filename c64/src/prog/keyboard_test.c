#include "memorymap.h"

//#define MEM_RAM  0x0000 // - 0x07FF
//#define MEM_DISP 0x8000 // - 0x83FF
//#define MEM_MOB  0x8400 // - 0x847F
//#define MEM_CONF 0x8600 // - 0x861F
//#define MEM_FONT 0x9000 // - 0x9FFF
//#define MEM_ROM  0xF800 // - 0xFFFF

void __fastcall__ reset(void)
{
loop:
   __asm__("LDA %w", VGA_KEY);
   __asm__("JMP %g", loop);
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

