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
      uint16_t s = t/100;
      uint16_t g = t-s*100;

      printf("%2d.%02d : %02x\n", s, g, ev);
   }

} // end of main

