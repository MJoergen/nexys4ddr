/*
 * Multiply two signed 8-bit numbers
 * to get a signed 16-bit result
 *
 * The method used is a*b = (a+b)^2/4 - (a-b)^2/4.
 * In other words a*b = f(a+b) - f(a-b), where f(x) = x^2/4.
 *
 * The fractional part of f(x) will either be 0 or 0.25. And the fractional part
 * will always be the same for the two evaluations of f(x). Therefore,
 * it suffices to take the integer part (floor) of f(x).
 *
 * Since -128 <= a,b <= 127 we then have
 * -255 <= a+b,a-b <= 255.
 * Since f(x) is even, we take the absolute value of x, i.e. of a+b and a-b.
 * The evaluation of f(x) is done via table-lookup.
 * 
 * When evaluating a+b (and a-b), the result is 9 bit, where the 9'th bit is in the carry.
 * The carry acts as the sign of the result, and if set, the result is to be negated.
 */

#include "zeropage.h"

// The two numbers are in A and X.
// The result has MSB in X and LSB in A.
void __fastcall__ smult(void)
{
   __asm__("STA %b", ZP_SMULT_A);
   __asm__("TXA");
   __asm__("STA %b", ZP_SMULT_X);
   __asm__("EOR %b", ZP_SMULT_A);
   __asm__("BMI %g", negative);

   __asm__("LDA %b", ZP_SMULT_X);
   __asm__("CLC");
   __asm__("ADC %b", ZP_SMULT_A);   // A+X
   __asm__("BCC %g", noNegate);

   __asm__("EOR #$FF"); // Negate
   __asm__("ADC #$00"); // Increment. Carry is always set here.
   
noNegate:
   __asm__("TAX");      // Move |A+X| to X
   __asm__("LDA $0600,X");
   __asm__("STA %b", ZP_SMULT_T1);
   __asm__("LDA $0700,X");
   __asm__("STA %b", ZP_SMULT_T2);

   __asm__("LDA %b", ZP_SMULT_A);
   __asm__("SEC");
   __asm__("SBC %b", ZP_SMULT_X);   // A-X
   __asm__("BCS %g", noNegate2);

   __asm__("EOR #$FF"); // Negate
   __asm__("ADC #$01"); // Increment. Carry is always clear here.
   
noNegate2:
   __asm__("TAX");      // Move |A-X| to X
   __asm__("LDA $0600,X");
   __asm__("EOR #$FF");    // Negate
   __asm__("SEC");
   __asm__("ADC %b", ZP_SMULT_T1);
   __asm__("STA %b", ZP_SMULT_T1);

   __asm__("LDA $0700,X");
   __asm__("EOR #$FF");
   __asm__("ADC %b", ZP_SMULT_T2);
   __asm__("TAX");      // Move MSB to X
   __asm__("LDA %b", ZP_SMULT_T1);
   __asm__("RTS"); 

negative:
   __asm__("LDA %b", ZP_SMULT_X);
   __asm__("CLC");
   __asm__("ADC %b", ZP_SMULT_A);   // A+X
   __asm__("BCS %g", noNegate3);

   __asm__("EOR #$FF"); // Negate
   __asm__("ADC #$01"); // Increment. Carry is always clear here.
   
noNegate3:
   __asm__("TAX");      // Move |A+X| to X
   __asm__("LDA $0600,X");
   __asm__("STA %b", ZP_SMULT_T1);
   __asm__("LDA $0700,X");
   __asm__("STA %b", ZP_SMULT_T2);

   __asm__("LDA %b", ZP_SMULT_A);
   __asm__("SEC");
   __asm__("SBC %b", ZP_SMULT_X);   // A-X
   __asm__("BCC %g", noNegate4);

   __asm__("EOR #$FF"); // Negate
   __asm__("ADC #$00"); // Increment. Carry is always set here.
   
noNegate4:
   __asm__("TAX");      // Move |A-X| to X
   __asm__("LDA $0600,X");
   __asm__("EOR #$FF");    // Negate
   __asm__("SEC");
   __asm__("ADC %b", ZP_SMULT_T1);
   __asm__("STA %b", ZP_SMULT_T1);

   __asm__("LDA $0700,X");
   __asm__("EOR #$FF");
   __asm__("ADC %b", ZP_SMULT_T2);
   __asm__("TAX");      // Move MSB to X
   __asm__("LDA %b", ZP_SMULT_T1);
   __asm__("RTS"); 
} // end of smult

// This initializes the are 0x0600 - 0x07FF
void __fastcall__ smult_init(void)
{
   __asm__("LDA #$00");
   __asm__("STA %b", ZP_SMULT_T1);
   __asm__("STA %b", ZP_SMULT_T2);
   __asm__("TAY");
   __asm__("TAX");
   __asm__("STA $0600,X");
   __asm__("STA $0700,X");
   __asm__("INX");

   __asm__("STA $0600,X");
   __asm__("STA $0700,X");
   __asm__("INX");
   __asm__("INY");

loop:
   __asm__("TYA");
   __asm__("CLC");
   __asm__("ADC %b", ZP_SMULT_T1);
   __asm__("STA %b", ZP_SMULT_T1);
   __asm__("STA $0600,X");
   __asm__("LDA %b", ZP_SMULT_T2);
   __asm__("ADC #$00");
   __asm__("STA %b", ZP_SMULT_T2);
   __asm__("STA $0700,X");
   __asm__("INX");
   __asm__("BEQ %g", end);

   __asm__("TYA");
   __asm__("CLC");
   __asm__("ADC %b", ZP_SMULT_T1);
   __asm__("STA %b", ZP_SMULT_T1);
   __asm__("STA $0600,X");
   __asm__("LDA %b", ZP_SMULT_T2);
   __asm__("ADC #$00");
   __asm__("STA %b", ZP_SMULT_T2);
   __asm__("STA $0700,X");
   __asm__("INY");
   __asm__("INX");
   __asm__("BNE %g", loop);

end:
   __asm__("RTS");
} // end of smult_init
