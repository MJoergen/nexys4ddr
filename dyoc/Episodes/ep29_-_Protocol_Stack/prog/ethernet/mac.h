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

extern const uint8_t myMacAddress[6];

void mac_rx(uint8_t *ptr, uint16_t length);
void mac_tx(uint8_t *dstMac, uint16_t typeLen, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_MAC_H_

