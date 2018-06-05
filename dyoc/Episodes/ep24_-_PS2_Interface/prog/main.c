#include <6502.h>             // CLI()
#include "printf.h"
#include "memorymap.h"

#define PIXELS_X 640
#define PIXELS_Y 480

// Called from crt0.s
void main()
{
   *VGA_PIX_Y_INT = 1;        // Let VGA generate interrupt at end of line 1.
   *IRQ_MASK = 2;             // Enable keyboard interupt.
   CLI();                     // Enable CPU interrupts.

   // Just go into a busy loop
   while (1)
   {
   }

} // end of main

// Called from crt0.s
void isr()
{
   if (*IRQ_STATUS & 2) // Reading the IRQ status clears it.
   {
      printfHex8(*KBD_DATA);
      printf("\n");
   }
} // end of irq

