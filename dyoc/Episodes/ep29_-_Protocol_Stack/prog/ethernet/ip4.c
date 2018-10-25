#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "ip4.h"
#include "icmp.h"
#include "udp.h"
#include "inet.h"
#include "mac.h"
#include "arp_table.h"
#include "arp.h"

// The hard-coded IP address of this device.
const uint8_t ip_myIpAddress[4]  = {192, 168, 1, 77};

uint16_t ip_id;

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

// ip       : Which IP address to send the payload to.
// protocol : What does the payload contain.
// ptr      : Points to first byte of payload (e.g. ICMP header).
// length   : Number of bytes in payload.
// Note: This function assumes that there are 34 free bytes in front of 'ptr'.
void ip_tx(uint8_t *ip, uint8_t protocol, uint8_t *ptr, uint16_t length)
{
   uint8_t *mac;  // Destination MAC address
   ipheader_t *ipHdr;

   // Find the MAC address associated with the IP address.
   mac = arp_table_lookup(ip);
   if (!mac)
   {
      // Mac address not found.
      printf("Unknown IP address. Sending ARP request\n");

      // Send an ARP request
      arp_tx(ARP_OPER_REQUEST, 0, ip);

      // While we're waiting for the ARP reply to return, we'll
      // just drop the tx packet for now.
      // We're relying on the protocol layer above to retransmit the
      // packet later on.
      return;
   }

   ip_id++; // Update sequence number

   ipHdr = (ipheader_t *) (ptr - sizeof(ipheader_t));

   // FIll in IP header
   ipHdr->verIHL     = 0x45;
   ipHdr->dscp       = 0;
   ipHdr->totLen     = htons(length + sizeof(ipheader_t));
   ipHdr->id         = htons(ip_id);
   ipHdr->frag       = 0;
   ipHdr->ttl        = 255;
   ipHdr->protocol   = protocol;
   ipHdr->chksum     = 0;
   memcpy(ipHdr->srcIP, ip_myIpAddress, 4);
   memcpy(ipHdr->destIP, ip, 4);
   ipHdr->chksum = ip_calcChecksum((uint16_t *) ipHdr, sizeof(ipheader_t)/2);

   mac_tx(mac, MAC_TYPELEN_IP4, (uint8_t *) ipHdr, length + sizeof(ipheader_t));
} // end of ip_tx


// When called, this function processes an IP packet.
// ptr    : Points to first byte of IP header.
// length : Total number of bytes in IP packet (including payload).
// This function will first check if the header checksum is valid and if the
// destination IP address matches ours.
// Then it will decode the protocol field in the IP header and call e.g. icmp_rx.
void ip_rx(uint8_t *ptr, uint16_t length)
{
   ipheader_t *ipHdr   = (ipheader_t *) ptr;
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
   if (memcmp(ipHdr->destIP, ip_myIpAddress, 4))
   {
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
   if (ntohs(ipHdr->totLen) != length)
   {
      printf("Incorrect IP length: 0x%04x. Expected: 0x%04x\n", ntohs(ipHdr->totLen), length);
      return;
   }

   switch (ipHdr->protocol)
   {
      case IP4_PROTOCOL_ICMP : icmp_rx(ipHdr->srcIP, nextPtr, nextLength); break;
      case IP4_PROTOCOL_UDP  : udp_rx(ipHdr->srcIP, nextPtr, nextLength); break;
      default                : printf("Unknown protocol: 0x%02x\n", ipHdr->protocol); break;
   }
} // end of ip_rx

