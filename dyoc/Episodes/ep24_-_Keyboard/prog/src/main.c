#include <6502.h>                // CLI()
#include <stdint.h>
#include "printf.h"
#include "keyboard.h"
#include "memorymap.h"

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
      uint8_t ev = kbd_buffer_pop();   // This does a BLOCKING wait.
      printfHex8(ev);
      printf("\n");
   }

} // end of main

