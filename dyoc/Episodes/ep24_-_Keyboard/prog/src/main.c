#include <stdint.h>
#include <stdio.h>
#include <time.h>

// This program is a simple key logger, that echoes the ASCII value of the key
// pressed onto the screen, as well as the time of the key press.

#define CLOCKS_PER_SEC 1000

void main()
{
   // Just go into a busy loop.
   while (1)
   {
      uint8_t ev = getchar();    // This does a BLOCKING wait.
      uint16_t t = clock();      // Returns elapsed time.
      uint16_t s = t/CLOCKS_PER_SEC;
      uint16_t g = t-s*CLOCKS_PER_SEC;

      printf("%2d.%02d : %02x\n", s, g, ev);
   }

} // end of main

