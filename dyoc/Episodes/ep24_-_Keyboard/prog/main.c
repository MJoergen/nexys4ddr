#include <6502.h>                // CLI()
#include "printf.h"
#include "memorymap.h"

#define PIXELS_X 640
#define PIXELS_Y 480

// Called from crt0.s
void main()
{
   uint8_t dummy;

   // Do a small timing measurement to begin with
   uint32_t t1 = *CPU_CYC;
   uint32_t t2 = *CPU_CYC;
   printfHex16(t2-t1);
   printf("\n");

   dummy = *IRQ_STATUS;             // Clear any pending interrupts.
   *IRQ_MASK = IRQ_KBD;             // Enable keyboard interrupts.
   CLI();                           // Enable CPU interrupts.

   // Just go into a busy loop
   while (1)
   {
   }

} // end of main

// Called from crt0.s
void isr()
{
   if (*IRQ_STATUS & IRQ_KBD)    // Reading the IRQ status clears it.
   {
      printfHex8(*KBD_DATA);
      printf("\n");
   }
} // end of irq

