#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "ethernet.h"

void processICMP(uint8_t *rdPtr, uint16_t frmLen)
{
   printf("ICMP!\n");
} // end of processICMP

void processIP(uint8_t *rdPtr, uint16_t frmLen)
{
   uint8_t protocol;

   if (frmLen < 34)
   {
      printf("Undersized IP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   protocol = rdPtr[23];

   switch (protocol)
   {
      case 0x01 : processICMP(rdPtr, frmLen); break;
      case 0x11 : processUDP(rdPtr, frmLen); break;
      default   : printf("Unknown protocol: 0x%02x\n", protocol); break;
   }
} // end of processIP

