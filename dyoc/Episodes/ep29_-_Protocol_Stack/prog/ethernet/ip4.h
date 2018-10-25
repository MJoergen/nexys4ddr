#ifndef _ETHERNET_IP4_H_
#define _ETHERNET_IP4_H_

#include <stdint.h>

typedef struct
{
   uint8_t  verIHL;     // version / header length
   uint8_t  dscp;       // type of service
   uint16_t totLen;     // total length
   uint16_t id;         // identification
   uint16_t frag;       // fragment offset
   uint8_t  ttl;        // time to live
   uint8_t  protocol;   // protocol
   uint16_t chksum;     // header checksum
   uint8_t  srcIP[4];   // source address
   uint8_t  destIP[4];  // destination address
} ipheader_t;

#define IP4_PROTOCOL_ICMP 0x01
#define IP4_PROTOCOL_UDP  0x11

// Contain the (hard-coded) IP address of this device.
extern const uint8_t ip_myIpAddress[4];

uint16_t ip_calcChecksum(uint16_t *ptr, uint16_t len);

// When called, this function processes an IP packet.
// ptr    : Points to first byte of IP header.
// length : Total number of bytes in IP packet (including payload).
// This function will first check if the header checksum is valid and if the
// destination IP address matches ours.
// Then it will decode the protocol field in the IP header and call e.g. icmp_rx.
void ip_rx(uint8_t *ptr, uint16_t length);

// ip       : Which IP address to send the payload to.
// protocol : What does the payload contain.
// ptr      : Points to first byte of payload (e.g. ICMP header).
// length   : Number of bytes in payload.
// Note: This function assumes that there are 34 free bytes in front of 'ptr'.
void ip_tx(uint8_t *ip, uint8_t protocol, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_IP4_H_

