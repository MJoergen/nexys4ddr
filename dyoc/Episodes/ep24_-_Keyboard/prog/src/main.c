#include <stdint.h>
#include <stdio.h>
#include <time.h>

void main()
{
   // Just go into a busy loop.
   while (1)
   {
      uint8_t ev = getchar();   // This does a BLOCKING wait.
      uint16_t t = clock();
      printf("%04x %02x\n", t, ev);
   }

} // end of main

