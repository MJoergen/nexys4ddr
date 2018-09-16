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
   while (1)
   {
      uint8_t x;

      while (MEMIO_STATUS->rx[62] == y)
      {
      }

      y = MEMIO_STATUS->rx[62];

      gotoxy(0, y%60);
      for (x=0; x<40; ++x)
      {
         uint8_t val = MEMIO_STATUS->rx[x];
         putx8(val);
      }
   }

} // end of main

