#include <6502.h>                // CLI()
#include "printf.h"
#include "memorymap.h"

#define PIXELS_X 640
#define PIXELS_Y 480

// Called from crt0.s
void main()
{
   *IRQ_MASK = IRQ_KBD;          // Enable keyboard interupt.
   CLI();                        // Enable CPU interrupts.

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

