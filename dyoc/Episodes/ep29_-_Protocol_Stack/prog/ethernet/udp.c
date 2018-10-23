#include <stdint.h>
#include <stdio.h>
#include "udp.h"

void udp_rx(uint8_t *ip, uint8_t *ptr, uint16_t length)
{
   printf("udp_rx!\n");
} // end of udp_rx

void udp_tx(uint8_t *ip, uint8_t *ptr, uint16_t length)
{
   printf("udp_tx!\n");
} // end of udp_tx

