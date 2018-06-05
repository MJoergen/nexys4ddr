#include <6502.h>                // CLI()
#include "printf.h"
#include "keyboard.h"
#include "memorymap.h"

// Called from crt0.s
void main()
{
   *IRQ_MASK = IRQ_KBD;          // Enable keyboard interupt.
   CLI();                        // Enable CPU interrupts.

   // Just go into a busy loop
   while (1)
   {
      char foo[2] = "0";
      foo[0] = kbd_getchar();
      printf(foo);
   }
} // end of main

