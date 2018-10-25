#ifndef _ETHERNET_ICMP_H_
#define _ETHERNET_ICMP_H_

#include <stdint.h>

typedef struct
{
   uint8_t  type;
   uint8_t  code;
   uint16_t chksum;
   uint16_t id;
   uint16_t seq;
} icmpheader_t;

#define ICMP_TYPE_REQUEST 8
#define ICMP_TYPE_REPLY   0

// When called, this function processes an IP packet.
// ip     : Which IP address did we receive from.
// ptr    : Points to first byte of ICMP header.
// length : Total number of bytes in ICMP packet (including payload).
// This function will first check if the header checksum is valid.
// Then it will examine the 'type' field and optionally call icmp_tx.
void icmp_rx(uint8_t *ip, uint8_t *ptr, uint16_t length);

// ip       : Which IP address to send the payload to.
// type     : What kind of packet to send.
// ptr      : Points to first byte of payload.
// length   : Number of bytes in payload.
// Note: This function assumes that there are 42 free bytes in front of 'ptr'.
void icmp_tx(uint8_t *ip, uint8_t type, uint16_t id, uint16_t seq, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_ICMP_H_

