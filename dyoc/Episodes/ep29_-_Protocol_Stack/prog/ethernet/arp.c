#include <stdint.h>
#include <stdio.h>
#include <string.h>  // memcpy
#include <stdlib.h>  // malloc
#include "arp.h"
#include "mac.h"
#include "ip4.h"
#include "inet.h"

void arp_tx(uint16_t oper, uint8_t *dstMac, uint8_t *dstIp)
{
   // Allocate space for the packet, including space for frame header and MAC header.
   arpheader_t *arpHdr = (arpheader_t *) malloc(sizeof(arpheader_t) + sizeof(macheader_t) + 2);

   // FIll in ARP header
   arpHdr->htype = htons(ARP_HTYPE_MAC);
   arpHdr->ptype = htons(ARP_PTYPE_IP4);
   arpHdr->hlen = ARP_HLEN_MAC;
   arpHdr->plen = ARP_PLEN_IP4;
   arpHdr->oper = htons(oper);

   switch (oper)
   {
      case ARP_OPER_REPLY : 
         memcpy(arpHdr->sha, myMacAddress, 6);
         memcpy(arpHdr->spa, myIpAddress, 4);
         memcpy(arpHdr->tha, dstMac, 6);
         memcpy(arpHdr->tpa, dstIp, 4);
         break;

      case ARP_OPER_REQUEST : 
         memcpy(arpHdr->sha, myMacAddress, 6);
         memcpy(arpHdr->spa, myIpAddress, 4);
         memset(arpHdr->tha, 0, 6);
         memcpy(arpHdr->tpa, dstIp, 4);
         break;

      default :
         break;
   } // end of switch

   mac_tx(dstMac, MAC_TYPELEN_ARP, (uint8_t *) arpHdr, sizeof(arpheader_t));

   free(arpHdr);
} // end of arp_reply_tx

void arp_rx(uint8_t *ptr, uint16_t length)
{
   arpheader_t *arpHdr = (arpheader_t *) ptr;

   if (length < sizeof(arpheader_t))
   {
      printf("Undersized ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   if (
      arpHdr->htype != htons(ARP_HTYPE_MAC) ||
      arpHdr->ptype != htons(ARP_PTYPE_IP4) ||
      arpHdr->hlen != ARP_HLEN_MAC ||
      arpHdr->plen != ARP_PLEN_IP4 ||
      arpHdr->oper != htons(ARP_OPER_REQUEST)
   )
   {
      printf("Malformed ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   printf("Got ARP for IP address: %d.%d.%d.%d\n", arpHdr->tpa[0], arpHdr->tpa[1], arpHdr->tpa[2], arpHdr->tpa[3]);

   if (memcmp(arpHdr->tpa, myIpAddress, 4))
      return;

   arp_tx(ARP_OPER_REPLY, arpHdr->sha, arpHdr->spa);

} // end of arp_rx

