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

void icmp_rx(uint8_t *ip, uint8_t *ptr, uint16_t length);
void icmp_tx(uint8_t *ip, uint8_t *ptr, uint16_t length);

#endif // _ETHERNET_ICMP_H_

