#include <6502.h>             // CLI()
#include "printf.h"
#include "memorymap.h"

// Called from crt0.s
void main()
{
   *VGA_PIX_Y_INT = 1;        // Let VGA generate interrupt at end of line 1.
   *IRQ_MASK = 1;             // Enable VGA IRQ Y interupt.
   CLI();                     // Enable CPU interrupts.

   // Just go into a busy loop
   while (1)
   {
   }

} // end of main

