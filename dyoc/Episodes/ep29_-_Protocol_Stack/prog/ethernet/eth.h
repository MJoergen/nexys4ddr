#ifndef _ETHERNET_ETH_H_
#define _ETHERNET_ETH_H_

#include <stdint.h>

// When called, this function processes the data received from the Ethernet Rx DMA.
// The first two bytes contain the total number of bytes (including these two bytes).
// The remainding bytes contain the Ethernet frame.
// This function will simply decode the length of the frame and call mac_rx.
void eth_rx(uint8_t *ptr);

// This is used when sending an Ethernet frame.
// ptr points to the start of the Ethernet frame, i.e. first byte of the MAC header.
// length contains number of bytes in the Ethernet frame, excl CRC.
// Note: This function assumes there are 2 spare bytes before 'ptr'.
void eth_tx(uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_ETH_H_

