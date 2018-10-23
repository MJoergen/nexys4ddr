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

extern const uint8_t myIpAddress[4];

uint16_t ip_calcChecksum(uint16_t *ptr, uint16_t len);
void ip_rx(uint8_t *ptr, uint16_t length);
void ip_tx(uint8_t *ip, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_IP4_H_

