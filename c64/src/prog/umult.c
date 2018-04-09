/*
 * Multiply two unsigned 8-bit numbers
 * to get an unsigned 16-bit result
 *
 */

#include "zeropage.h"

// The two numbers are in A and X.
// The result has MSB in X and LSB in A.
void __fastcall__ umult(void)
{
   __asm__("STA %b", ZP_UMULT_A);
   __asm__("TXA");
   __asm__("STA %b", ZP_UMULT_X);

   // Initialize result
   __asm__("LDA #$08");
   __asm__("STA %b", ZP_UMULT_C);
   __asm__("LDA #$00");
   __asm__("TAX");
   __asm__("TAY");

loop:
   // Multiply by 2
   __asm__("TYA");
   __asm__("CLC");
   __asm__("ROL A");
   __asm__("TAY");
   __asm__("TXA");
   __asm__("ROL A");
   __asm__("TAX");

   __asm__("LDA %b", ZP_UMULT_X);
   __asm__("ROL A");    // Carry is always clear here.
   __asm__("STA %b", ZP_UMULT_X);
   __asm__("BCC %g", noAdd);

   __asm__("TYA");
   __asm__("CLC");
   __asm__("ADC %b", ZP_UMULT_A);
   __asm__("TAY");
   __asm__("BCC %g", noAdd);
   __asm__("INX");

noAdd:
   __asm__("LDA %b", ZP_UMULT_C);
   __asm__("SEC");
   __asm__("SBC #$01");
   __asm__("STA %b", ZP_UMULT_C);
   __asm__("BNE %g", loop);

   __asm__("TYA");
   __asm__("RTS");

} // end of umult

