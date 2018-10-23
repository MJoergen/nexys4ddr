#ifndef _ETHERNET_ETH_H_
#define _ETHERNET_ETH_H_

#include <stdint.h>

void eth_rx(uint8_t *ptr);
void eth_tx(uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_ETH_H_

