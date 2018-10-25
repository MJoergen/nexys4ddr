#include <stdint.h>
#include <stdio.h>
#include <string.h>  // memcpy
#include <stdlib.h>  // malloc
#include "arp.h"
#include "mac.h"
#include "ip4.h"
#include "inet.h"
#include "arp_table.h"

// When called, this function processes an ARP frame.
// ptr    : Points to first byte of ARP header.
// length : Total number of bytes in ARP frame (header and payload combined).
// This function will decode the ARP packet and possibly call e.g. arp_tx.
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
      arpHdr->plen != ARP_PLEN_IP4)
   {
      printf("Malformed ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   switch (arpHdr->oper)
   {
      case htons(ARP_OPER_REQUEST) : 

         if (memcmp(arpHdr->tpa, ip_myIpAddress, 4))
            return;

         printf("Got ARP request!\n");

         // Insert source IP and MAC address into our ARP table.
         arp_table_insert(arpHdr->spa, arpHdr->sha);

         // Send an ARP reply
         arp_tx(ARP_OPER_REPLY, arpHdr->sha, arpHdr->spa);

         break;

      case htons(ARP_OPER_REPLY) : 

         if (memcmp(arpHdr->tpa, ip_myIpAddress, 4))
            return;

         printf("Got ARP reply!\n");

         // Insert source IP and MAC address into our ARP table.
         arp_table_insert(arpHdr->spa, arpHdr->sha);

         break;

      default :
         printf("Malformed ARP.\n");
         while(1) {} // Infinite loop to indicate error
   }
} // end of arp_rx


// oper    : Which type of ARP packet to send.
// dstMac  : Which MAC address to send to.
// dstIp   : Which IP address to send to.
void arp_tx(uint16_t oper, uint8_t *dstMac, uint8_t *dstIp)
{
   // Number of bytes in front of ARP header.
   uint16_t headroom = sizeof(macheader_t) + 2;

   // Allocate space for the packet, including space for frame header and MAC header.
   arpheader_t *arpHdr = (arpheader_t *) ((uint8_t *) malloc(headroom + sizeof(arpheader_t)) + headroom);

   // FIll in ARP header
   arpHdr->htype = htons(ARP_HTYPE_MAC);
   arpHdr->ptype = htons(ARP_PTYPE_IP4);
   arpHdr->hlen = ARP_HLEN_MAC;
   arpHdr->plen = ARP_PLEN_IP4;
   arpHdr->oper = htons(oper);

   switch (oper)
   {
      case ARP_OPER_REPLY : 
         memcpy(arpHdr->sha, mac_myMacAddress, 6);
         memcpy(arpHdr->spa, ip_myIpAddress, 4);
         memcpy(arpHdr->tha, dstMac, 6);
         memcpy(arpHdr->tpa, dstIp, 4);
         break;

      case ARP_OPER_REQUEST : 
         memcpy(arpHdr->sha, mac_myMacAddress, 6);
         memcpy(arpHdr->spa, ip_myIpAddress, 4);
         memset(arpHdr->tha, 0, 6);
         memcpy(arpHdr->tpa, dstIp, 4);
         break;

      default :
         break;
   } // end of switch

   mac_tx(dstMac, MAC_TYPELEN_ARP, (uint8_t *) arpHdr, sizeof(arpheader_t));

   free(arpHdr);
} // end of arp_tx

