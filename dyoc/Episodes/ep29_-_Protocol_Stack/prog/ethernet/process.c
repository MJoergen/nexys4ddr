#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "ethernet.h"

void processFrame(uint8_t *rdPtr, uint16_t frmLen)
{
   macheader_t *macHdr = (macheader_t *) (rdPtr);

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

   switch (ntoh16(macHdr->typeLen))
   {
      case 0x0806 : processARP(rdPtr, frmLen); break;
      case 0x0800 : processIP(rdPtr, frmLen); break;
      default     : printf("Unknown typelen: 0x%04x\n", ntoh16(macHdr->typeLen)); break;
   }
} // end of processFrame

