#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "mac.h"
#include "ip4.h"
#include "arp.h"
#include "eth.h"
#include "inet.h"

const uint8_t myMacAddress[6] = {0x70, 0x4D, 0x7B, 0x11, 0x22, 0x33};  // AsustekC

void mac_rx(uint8_t *ptr, uint16_t length)
{
   macheader_t *macHdr = (macheader_t *) ptr;
   uint8_t *nextPtr    = ptr + sizeof(macheader_t);
   uint16_t nextLength = length - sizeof(macheader_t);

   if (length < sizeof(macheader_t))
   {
      printf("Undersize.\n");
      while(1) {} // Infinite loop to indicate error
   }

   if (length > 1514)
   {
      printf("Oversize.\n");
      while(1) {} // Infinite loop to indicate error
   }

   switch (ntohs(macHdr->typeLen))
   {
      case MAC_TYPELEN_ARP :
         arp_rx(nextPtr, nextLength);
         break;

      case MAC_TYPELEN_IP4 :
         ip_rx(nextPtr, nextLength);
         break;

      default :
         printf("Unknown typelen: 0x%04x\n", ntohs(macHdr->typeLen));
         break;
   }
} // end of mac_rx

void mac_tx(uint8_t *dstMac, uint16_t typeLen, uint8_t *ptr, uint16_t length)
{
   macheader_t *macHdr = (macheader_t *) (ptr - sizeof(macheader_t));

   // Insert MAC header
   memcpy(macHdr->destMac, dstMac, 6);
   memcpy(macHdr->srcMac,  myMacAddress,  6);
   macHdr->typeLen = htons(typeLen);

   eth_tx((uint8_t *) macHdr, length + sizeof(macheader_t));
} // end of mac_tx

