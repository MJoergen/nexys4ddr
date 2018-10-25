#ifndef _ETHERNET_MAC_H_
#define _ETHERNET_MAC_H_

#include <stdint.h>

typedef struct
{
   uint8_t  destMac[6]; // destination mac address
   uint8_t  srcMac[6];  // source mac address
   uint16_t typeLen;    // type / length
} macheader_t;

#define MAC_TYPELEN_IP4 0x0800
#define MAC_TYPELEN_ARP 0x0806

extern const uint8_t mac_myMacAddress[6];

// When called, this function processes a MAC frame.
// ptr    : Points to first byte of MAC header.
// length : Total number of bytes in MAC frame (excl CRC).
// This function will decode the typeLen field in the MAC header and call e.g. arp_rx.
void mac_rx(uint8_t *ptr, uint16_t length);

// dstMac  : Which MAC address to send the payload to.
// typeLen : What does the payload contain
// ptr     : Points to first byte of payload (e.g. IP header).
// length  : Number of bytes in payload
// Note: This function assumes that there are 14 free bytes in front of 'ptr'.
void mac_tx(uint8_t *dstMac, uint16_t typeLen, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_MAC_H_

