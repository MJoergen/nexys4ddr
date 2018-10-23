#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "ip4.h"
#include "icmp.h"
#include "udp.h"
#include "inet.h"

const uint8_t myIpAddress[4]  = {192, 168, 1, 77};

uint16_t ip_calcChecksum(uint16_t *ptr, uint16_t len)
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

   return retVal;
} // end of calcChecksum

void ip_tx(uint8_t *ip, uint8_t *ptr, uint16_t length)
{
} // end of ip_tx

void ip_rx(uint8_t *ptr, uint16_t length)
{
   ipheader_t *ipHdr = (ipheader_t *) ptr;
   uint8_t *nextPtr    = ptr + sizeof(ipheader_t);
   uint16_t nextLength = length - sizeof(ipheader_t);

   if (length < 34)
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

   // Check IP header length
   if ((ipHdr->verIHL & 0x0F) != 0x05)
   {
      printf("Unexpected IP header length: %02x\n", ipHdr->verIHL);
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
   if (ip_calcChecksum((uint16_t *) ipHdr, 10) != 0)
   {
      printf("IP header checksum error\n");
      return;
   }

   // Check IP length
   if (ntohs(ipHdr->totLen) != length - 14)
   {
      printf("Incorrect IP length: 0x%04x. Expected: 0x%04x\n", ntohs(ipHdr->totLen), length - 14);
      return;
   }

   switch (ipHdr->protocol)
   {
      case IP4_PROTOCOL_ICMP : icmp_rx(ipHdr->srcIP, nextPtr, nextLength); break;
      case IP4_PROTOCOL_UDP  : udp_rx(ipHdr->srcIP, nextPtr, nextLength); break;
      default                : printf("Unknown protocol: 0x%02x\n", ipHdr->protocol); break;
   }
} // end of ip_tx

