#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "ethernet.h"

uint16_t calcChecksum(uint16_t *ptr, uint16_t len)
{
   uint16_t i;
   uint32_t checksum = 0;
   uint16_t retVal;

   for (i=0; i<len; ++i)
   {
      checksum += ptr[i];
   }
   checksum = (checksum >> 16) + (checksum & 0xFFFF);

   retVal = ~(checksum & 0xFFFF);

   //printf("checksum=%04x\n", retVal);

   return retVal;
} // end of calcChecksum

void processIP(uint8_t *rdPtr, uint16_t frmLen)
{
   ipheader_t *ipHdr = (ipheader_t *) (rdPtr+14);

   if (frmLen < 34)
   {
      printf("Undersized IP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   // Check IP version
   if ((ipHdr->verIHL & 0xF0) != 0x40)
   {
      printf("Unexpected IP version field: %02x\n", ipHdr->verIHL);
      return;
   }

   // Check IP address
   if (memcmp(ipHdr->destIP, myIpAddress, 4))
   {
      printf("Not my IP address: %d.%d.%d.%d\n", ipHdr->destIP[0], ipHdr->destIP[1], ipHdr->destIP[2], ipHdr->destIP[3]);
      return;
   }

   // Check IP fragmentation
   if (ipHdr->frag & 0xBF)
   {
      printf("Unexpected IP fragmentation: %02x\n", ipHdr->frag);
      return;
   }

   // Check IP header checksum
   if (calcChecksum((uint16_t *) ipHdr, 10) != 0)
   {
      printf("IP header checksum error\n");
      return;
   }

   // Check IP length
   if (ntoh16(ipHdr->totLen) != frmLen - 14)
   {
      printf("Incorrect IP length: 0x%04x. Expected: 0x%04x\n", ntoh16(ipHdr->totLen), frmLen - 14);
      return;
   }

   switch (ipHdr->protocol)
   {
      case 0x01 : processICMP(rdPtr, frmLen); break;
      case 0x11 : processUDP(rdPtr, frmLen); break;
      default   : printf("Unknown protocol: 0x%02x\n", ipHdr->protocol); break;
   }
} // end of processIP

