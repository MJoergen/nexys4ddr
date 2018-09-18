#include <stdint.h>
#include <conio.h>
#include "memorymap.h"

static void putx8(uint8_t x)
{
   const char hex[16] = "0123456789ABCDEF";
   cputc(hex[(x>>4) & 0x0F]);
   cputc(hex[(x>>0) & 0x0F]);
}

void main(void)
{
   uint8_t y = 0;
   uint8_t *pStart;
   uint8_t *pEnd;
   uint8_t cnt = 0;

   pStart = (uint8_t *) (MEMIO_STATUS->ethAddr);

   while (1)
   {
      uint8_t x;

      // Wait until a new packet has been received.
      while (MEMIO_STATUS->ethCnt == y)
      {
         cnt += 1;
      }

      pEnd = (uint8_t *) (MEMIO_STATUS->ethAddr);
      y = MEMIO_STATUS->ethCnt;

      // Dump first 40 bytes of packet onto screen
      gotoxy(0, y%60);
      for (x=0; x<40; ++x)
      {
         uint8_t val = pStart[x];
         putx8(val);
      }

      // Next packet starts right after the previous
      pStart = pEnd;
   }

} // end of main

