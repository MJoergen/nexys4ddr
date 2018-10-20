#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include "memorymap.h"
#include "ethernet.h"

void sendICMPReply(const uint8_t mac[6], const uint8_t ip[4], const icmpheader_t *icmp, uint16_t frmLen)
{
   uint8_t counter = 0;

   uint8_t *pkt = (uint8_t *) malloc(1516); // Allocate space for the packet

   macheader_t *macHdr   = (macheader_t *) (pkt+2);      // Start of MAC header
   ipheader_t *ipHdr     = (ipheader_t *) &macHdr[1];    // Start of IP header
   icmpheader_t *icmpHdr = (icmpheader_t *) &ipHdr[1];   // Start of ICMP header

   // Fill in MAC header
   memcpy(macHdr->destMac, mac, 6);
   memcpy(macHdr->srcMac, myMacAddress, 6);
   macHdr->typeLen = hton16(0x0800);   // IP

   // FIll in IP header
   ipHdr->verIHL   = 0x45;
   ipHdr->dscp     = 0;
   ipHdr->totLen   = hton16(frmLen - 14);     // total length
   ipHdr->id       = 0;
   ipHdr->frag     = 0x40;
   ipHdr->ttl      = 0xFF;
   ipHdr->protocol = 1;   // ICMP
   ipHdr->chksum   = 0;
   memcpy(ipHdr->srcIP, myIpAddress, 4);
   memcpy(ipHdr->destIP, ip, 4);
   ipHdr->chksum = calcChecksum((uint16_t *) ipHdr, 10);

   // Fill in ICMP header
   memcpy(icmpHdr, icmp, frmLen-34);
   icmpHdr->type = 0;
   icmpHdr->chksum = 0;
   icmpHdr->chksum = calcChecksum((uint16_t *) icmpHdr, (frmLen-34)/2);

   // Fill in length
   *((uint16_t *)pkt) = frmLen+2;

   // Pad packet if length is less than 60 bytes.
   if (*((uint16_t *)pkt) < 62)
   {
      memset(pkt + *((uint16_t *)pkt), 0, 62 - *((uint16_t *)pkt));
      *((uint16_t *)pkt) = 62;
   }

   txFrame(pkt);

   free(pkt);
} // end of sendARPReply

void processICMP(uint8_t *rdPtr, uint16_t frmLen)
{
   macheader_t *macHdr   = (macheader_t *)  (rdPtr);
   ipheader_t *ipHdr     = (ipheader_t *)   (rdPtr+14);
   icmpheader_t *icmpHdr = (icmpheader_t *) (rdPtr+34);

   //printf("ICMP: length=%d\n", frmLen-34);

   // Check ICMP header checksum
   if (calcChecksum((uint16_t *) icmpHdr, (frmLen-34)/2))
   {
      printf("ICMP header checksum error\n");
      return;
   }

   // Check ICMP type
   if (icmpHdr->type != 8)
   {
      printf("Unexpected ICMP type\n");
      return;
   }

   // Check ICMP code
   if (icmpHdr->code != 0)
   {
      printf("Unexpected ICMP code\n");
      return;
   }

   printf("ICMP!\n");

   sendICMPReply(macHdr->srcMac, ipHdr->srcIP, icmpHdr, frmLen);

} // end of processICMP

