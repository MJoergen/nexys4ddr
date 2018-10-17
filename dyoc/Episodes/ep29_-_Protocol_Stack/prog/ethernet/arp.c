#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "memorymap.h"
#include "ethernet.h"

const uint8_t arpHeaderRequest[8] = {0x00, 0x01, 0x08, 0x00, 0x06, 0x04, 0x00, 0x01};
const uint8_t arpHeaderReply[8]   = {0x00, 0x01, 0x08, 0x00, 0x06, 0x04, 0x00, 0x02};
const uint8_t myMacAddress[6] = {0x70, 0x4D, 0x7B, 0x11, 0x22, 0x33};  // AsustekC
const uint8_t myIpAddress[4]  = {192, 168, 1, 77};

void sendARPReply(const uint8_t mac[6], const uint8_t ip[4])
{
   uint8_t pkt[28+14+2];   // Allocate space for the packet

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
   arpHdr->plen = 6;
   arpHdr->oper = hton16(0x0002);
   memcpy(arpHdr->sha, myMacAddress, 6);
   memcpy(arpHdr->spa, myIpAddress, 4);
   memcpy(arpHdr->tha, mac, 6);
   memcpy(arpHdr->tpa, ip, 4);

   // Fill in length
   *((uint16_t *)pkt) = (uint8_t *) &arpHdr[1] - pkt;

   // Send reply
   MEMIO_CONFIG->ethTxPtr  = (uint16_t) pkt;
   MEMIO_CONFIG->ethTxCtrl = 1;

   // Wait until frame has been consumed by TxDMA.
   while (MEMIO_CONFIG->ethTxCtrl)
   {}
} // end of sendARPReply


void processARP(uint8_t *rdPtr, uint16_t frmLen)
{
   if (frmLen < 42)
   {
      printf("Undersized ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   if (memcmp(rdPtr+14, arpHeaderRequest, 8))
   {
      printf("Malformened ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   printf("Got ARP for IP address: %d.%d.%d.%d\n", rdPtr[38], rdPtr[39], rdPtr[40], rdPtr[41]);

   if (memcmp(rdPtr+38, myIpAddress, 4))
      return;

   printf("Bingo!\n");

   sendARPReply(rdPtr+22, rdPtr+28);

} // end of processARP

