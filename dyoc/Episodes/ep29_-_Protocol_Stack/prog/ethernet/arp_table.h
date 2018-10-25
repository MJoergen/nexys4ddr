#ifndef _ETHERNET_ARP_TABLE_H_
#define _ETHERNET_ARP_TABLE_H_

#include <stdint.h>

// Initializes the ARP table
void arp_table_init(void);

// Searches the ARP table for the given IP address
// If found, returns pointer to the associated MAC address.
// If not fount, return 0.
uint8_t *arp_table_lookup(uint8_t *ip);

// Inserts a new IP and MAC address pair.
// If the IP address exists already, the existing entry will be destroyed.
void arp_table_insert(uint8_t *ip, uint8_t *mac);

#endif // _ETHERNET_ARP_TABLE_H_

