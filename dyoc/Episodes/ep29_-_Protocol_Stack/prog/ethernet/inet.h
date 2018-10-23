#ifndef _ETHERNET_INET_H_
#define _ETHERNET_INET_H_

#define htons(x) ((x>>8) | ((x&0xFF) << 8))
#define ntohs(x) htons(x)

#endif // _ETHERNET_INET_H_

