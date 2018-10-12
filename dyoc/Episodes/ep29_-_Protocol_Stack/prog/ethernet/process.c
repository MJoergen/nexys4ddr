#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "ethernet.h"

void processFrame(uint8_t *rdPtr, uint16_t frmLen)
{
   uint16_t typeLen;

   if (frmLen < 14)
   {
      printf("Undersize.\n");
      while(1) {} // Infinite loop to indicate error
   }

   if (frmLen > 1514)
   {
      printf("Oversize.\n");
      while(1) {} // Infinite loop to indicate error
   }

   typeLen = (rdPtr[12] << 8) | rdPtr[13];

   switch (typeLen)
   {
      case 0x0806 : processARP(rdPtr, frmLen); break;
      case 0x0800 : processIP(rdPtr, frmLen); break;
      default     : printf("Unknown typelen: 0x%04x\n", typeLen); break;
   }
} // end of processFrame

