#include <stdint.h>
#include <stdlib.h>
#include <conio.h>
#include "memorymap.h"

static void putx8(uint8_t x)
{
   static const char hex[16] = "0123456789ABCDEF";
   cputc(hex[(x>>4) & 0x0F]);
   cputc(hex[(x>>0) & 0x0F]);
}

void main(void)
{
   // Allocate receive buffer. This will never be free'd.
   uint8_t *pBuf = (uint8_t *) malloc(2000);

   // Configure Ethernet DMA
   MEMIO_CONFIG->ethStart  = (uint16_t) pBuf;
   MEMIO_CONFIG->ethEnd    = (uint16_t) pBuf + 2000;
   MEMIO_CONFIG->ethRdPtr  = MEMIO_CONFIG->ethStart;
   MEMIO_CONFIG->ethEnable = 1;
   
   // Wait for data to be received, and print to the screen
   while (1)
   {
      if (MEMIO_CONFIG->ethRdPtr == MEMIO_STATUS->ethWrPtr)
         continue;   // Go back and wait for data

      putx8(*(uint8_t *)MEMIO_CONFIG->ethRdPtr);

      if (MEMIO_CONFIG->ethRdPtr < MEMIO_CONFIG->ethEnd)
      {
         MEMIO_CONFIG->ethRdPtr += 1;
      }
      else
      {
         MEMIO_CONFIG->ethRdPtr = MEMIO_CONFIG->ethStart;
      }
   }

} // end of main

