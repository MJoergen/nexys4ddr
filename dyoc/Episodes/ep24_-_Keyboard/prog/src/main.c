#include <6502.h>                // CLI()
#include <stdint.h>
#include <stdio.h>
#include "keyboard.h"
#include "memorymap.h"           // IRQ_KBD_NUM

void main()
{
   uint8_t dummy;

   // Do a small timing measurement to begin with
   uint32_t t1 = *CPU_CYC;
   uint32_t t2 = *CPU_CYC;
   printf("%04x\n", t2-t1);

   dummy = *IRQ_STATUS;             // Clear any pending interrupts.
   *IRQ_MASK = 1<<IRQ_KBD_NUM;      // Enable keyboard interrupts.
   CLI();                           // Enable CPU interrupts.

   // Just go into a busy loop.
   while (1)
   {
      uint8_t ev = kbd_buffer_pop();   // This does a BLOCKING wait.
      printf("%02x\n", ev);
   }

} // end of main

