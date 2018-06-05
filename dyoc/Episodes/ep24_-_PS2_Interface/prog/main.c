#include <6502.h>             // CLI()
#include "printf.h"
#include "memorymap.h"

#define PIXELS_X 640
#define PIXELS_Y 480

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

// Called from crt0.s
void isr()
{
   if (*IRQ_STATUS & 1) // Reading the IRQ status clears it.
   {
      uint16_t line = *VGA_PIX_Y_INT + 1;

      *VGA_CHAR_BG_COL = line & 0xFF;

      if (line < PIXELS_Y)
         *VGA_PIX_Y_INT = line;
      else
         *VGA_PIX_Y_INT = 0;
   }
} // end of irq

