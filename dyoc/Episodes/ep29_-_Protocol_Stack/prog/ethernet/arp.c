#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include "memorymap.h"
#include "ethernet.h"

const uint8_t myMacAddress[6] = {0x70, 0x4D, 0x7B, 0x11, 0x22, 0x33};  // AsustekC
const uint8_t myIpAddress[4]  = {192, 168, 1, 77};

void sendARPReply(const uint8_t mac[6], const uint8_t ip[4])
{
   uint8_t counter = 0;

   uint8_t *pkt = (uint8_t *) malloc(1516); // Allocate space for the packet

   macheader_t *macHdr = (macheader_t *) (pkt+2);     // Start of MAC header
   arpheader_t *arpHdr = (arpheader_t *) &macHdr[1];   // Start of ARP header

   // Fill in MAC header
   memcpy(macHdr->destMac, mac, 6);
   memcpy(macHdr->srcMac, myMacAddress, 6);
   macHdr->typeLen = hton16(0x0806);

   // FIll in ARP header
   arpHdr->htype = hton16(0x0001);
   arpHdr->ptype = hton16(0x0800);
   arpHdr->hlen = 6;
   arpHdr->plen = 4;
   arpHdr->oper = hton16(0x0002);
   memcpy(arpHdr->sha, myMacAddress, 6);
   memcpy(arpHdr->spa, myIpAddress, 4);
   memcpy(arpHdr->tha, mac, 6);
   memcpy(arpHdr->tpa, ip, 4);

   // Fill in length
   *((uint16_t *)pkt) = (uint8_t *) &arpHdr[1] - pkt;

   // Pad packet if length is less than 60 bytes.
   if (*((uint16_t *)pkt) < 62)
   {
      memset(pkt + *((uint16_t *)pkt), 0, 62 - *((uint16_t *)pkt));
      *((uint16_t *)pkt) = 62;
   }

   txFrame(pkt);

   free(pkt);
} // end of sendARPReply


void processARP(uint8_t *rdPtr, uint16_t frmLen)
{
   arpheader_t *arpHdr = (arpheader_t *) (rdPtr+14);

   if (frmLen < 42)
   {
      printf("Undersized ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   if (
      arpHdr->htype != hton16(0x0001) ||
      arpHdr->ptype != hton16(0x0800) ||
      arpHdr->hlen != 6 ||
      arpHdr->plen != 4 ||
      arpHdr->oper != hton16(0x0001)
   )
   {
      printf("Malformed ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   printf("Got ARP for IP address: %d.%d.%d.%d\n", arpHdr->tpa[0], arpHdr->tpa[1], arpHdr->tpa[2], arpHdr->tpa[3]);

   if (memcmp(arpHdr->tpa, myIpAddress, 4))
      return;

   printf("Bingo!\n");

   sendARPReply(arpHdr->sha, arpHdr->spa);

} // end of processARP

