#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "memorymap.h"

const uint8_t arpHeader[10]   = {0x08, 0x06, 0x00, 0x01, 0x08, 0x00, 0x06, 0x04, 0x00, 0x01};
const uint8_t myMacAddress[6] = {0x70, 0x4D, 0x7B, 0x11, 0x22, 0x33};  // AsustekC
const uint8_t myIpAddress[4]  = {192, 168, 1, 77};

void processARP(uint8_t *rdPtr, uint16_t frmLen)
{
   if (frmLen < 42)
   {
      printf("Undersized ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   if (memcmp(rdPtr+12, arpHeader, 10))
   {
      printf("Malformened ARP.\n");
      while(1) {} // Infinite loop to indicate error
   }

   printf("Got ARP for IP address: %d.%d.%d.%d\n", rdPtr[38], rdPtr[39], rdPtr[40], rdPtr[41]);

   if (memcmp(rdPtr+38, myIpAddress, 4))
      return;

   printf("Bingo!\n");

   // Build new MAC header
   memcpy(rdPtr, rdPtr+22, 6);
   memcpy(rdPtr+6, myMacAddress, 6);

   // Build new ARP header
   rdPtr[21] = 2; // ARP Reply
   memcpy(rdPtr+32, rdPtr+22, 10); // Copy original senders MAC and IP address to the target.
   memcpy(rdPtr+22, myMacAddress, 6);
   memcpy(rdPtr+28, myIpAddress, 4);

   // Send reply
   MEMIO_CONFIG->ethTxPtr  = (uint16_t) rdPtr - 2;
   MEMIO_CONFIG->ethTxCtrl = 1;

   // Wait until frame has been consumed by TxDMA.
   while (MEMIO_CONFIG->ethTxCtrl)
   {}
} // end of processARP

