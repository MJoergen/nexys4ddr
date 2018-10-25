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
   printf("arp_table_init\n");

   arp_table_head = 0;
} // end of arp_table_init

uint8_t *arp_table_lookup(uint8_t *ip)
{
   struct arp_table_entry_t *elem = arp_table_head;

   printf("arp_table_lookup for %d.%d.%d.%d\n", ip[0], ip[1], ip[2], ip[3]);

   while (elem != 0)
   {
      printf("arp_table_lookup. Searching element %p: %d.%d.%d.%d\n", elem,
            elem->ip[0], elem->ip[1], elem->ip[2], elem->ip[3]);
      if (!memcmp(elem->ip, ip, 4))
      {
         printf("arp_table_lookup: Found %02x%02x%02x:%02x%02x%02x\n",
               elem->mac[0], elem->mac[1], elem->mac[2],
               elem->mac[3], elem->mac[4], elem->mac[5]);
         return elem->mac;
      }

      printf("arp_table_lookup: Skipping to next element\n");
      elem = elem->next;
   }

   printf("arp_table_lookup: Not found\n");
   return 0;
} // end of arp_table_lookup

void arp_table_insert(uint8_t *ip, uint8_t *mac)
{
   uint8_t *mac_table;
   struct arp_table_entry_t *new_entry;

   printf("arp_table_insert for %d.%d.%d.%d -> ", ip[0], ip[1], ip[2], ip[3]);
   printf("%02x%02x%02x:%02x%02x%02x\n",
         mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

   // Was IP address already in arp table ?
   mac_table = arp_table_lookup(ip);
   if (mac_table)
   {
      // Update existing entry
      memcpy(mac_table, mac, 6);
      printf("arp_table_insert: Updated existing entry %p\n", mac_table);
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

