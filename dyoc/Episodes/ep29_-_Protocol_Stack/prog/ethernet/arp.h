#ifndef _ETHERNET_ARP_H_
#define _ETHERNET_ARP_H_

#include <stdint.h>

typedef struct
{
   uint16_t htype;      // hardware type
   uint16_t ptype;      // protocol type
   uint8_t  hlen;       // hardware address length
   uint8_t  plen;       // protocol address length
   uint16_t oper;       // operation
   uint8_t  sha[6];     // sender hardware address
   uint8_t  spa[4];     // sender protocol address
   uint8_t  tha[6];     // target hardware address
   uint8_t  tpa[4];     // target protocol address
} arpheader_t;

#define ARP_HTYPE_MAC      0x0001
#define ARP_PTYPE_IP4      0x0800
#define ARP_HLEN_MAC       6
#define ARP_PLEN_IP4       4
#define ARP_OPER_REQUEST   1
#define ARP_OPER_REPLY     2

// When called, this function processes an ARP frame.
// ptr    : Points to first byte of ARP header.
// length : Total number of bytes in ARP frame (header and payload combined).
// This function will decode the ARP packet and possibly call e.g. arp_tx.
void arp_rx(uint8_t *ptr, uint16_t length);

// oper    : Which type of ARP packet to send.
// dstMac  : Which MAC address to send to.
// dstIp   : Which IP address to send to.
void arp_tx(uint16_t oper, uint8_t *dstMac, uint8_t *dstIp);

#endif // _ETHERNET_ARP_H_

