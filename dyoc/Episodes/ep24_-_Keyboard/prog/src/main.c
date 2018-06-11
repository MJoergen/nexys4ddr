#include <stdint.h>
#include <stdio.h>
#include "keyboard.h"            // kbd_buffer_pop()
#include "memorymap.h"           // CPU_CYC

void main()
{
   // Just go into a busy loop.
   while (1)
   {
      uint8_t ev = kbd_buffer_pop();   // This does a BLOCKING wait.
      uint16_t t = *(uint16_t *)CPU_CYC;
      printf("%04x %02x\n", t, ev);
   }

} // end of main

