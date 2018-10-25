#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "arp_table.h"

struct arp_table_entry_t
{
   struct  arp_table_entry_t *next;
   uint8_t ip[4];
   uint8_t mac[6];
};

// Head of linked list
struct arp_table_entry_t *arp_table_head;

void arp_table_init(void)
{
   arp_table_head = 0;
} // end of arp_table_init

uint8_t *arp_table_lookup(uint8_t *ip)
{
   struct arp_table_entry_t *elem = arp_table_head;

   while (elem != 0)
   {
      if (!memcmp(elem->ip, ip, 4))
      {
         return elem->mac;
      }

      elem = elem->next;
   }

   return 0;
} // end of arp_table_lookup

void arp_table_insert(uint8_t *ip, uint8_t *mac)
{
   uint8_t *mac_table;
   struct arp_table_entry_t *new_entry;

   // Was IP address already in arp table ?
   mac_table = arp_table_lookup(ip);
   if (mac_table)
   {
      // Update existing entry
      memcpy(mac_table, mac, 6);
      return;
   }

   // Create new entry in arp table
   new_entry = (struct arp_table_entry_t *) malloc(sizeof(struct arp_table_entry_t));
   memcpy(new_entry->ip, ip, 4);
   memcpy(new_entry->mac, mac, 6);

   // Insert at head of linked list
   new_entry->next = arp_table_head;
   arp_table_head = new_entry;
} // end of arp_table_insert

