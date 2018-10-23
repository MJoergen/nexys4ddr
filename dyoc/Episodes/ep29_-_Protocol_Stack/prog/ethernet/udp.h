#ifndef _ETHERNET_UDP_H_
#define _ETHERNET_UDP_H_

#include <stdint.h>

void udp_rx(uint8_t *ip, uint8_t *ptr, uint16_t length);
void udp_tx(uint8_t *ip, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_UDP_H_

