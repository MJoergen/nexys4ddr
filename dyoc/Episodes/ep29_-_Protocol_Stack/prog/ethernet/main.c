#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>
#include "memorymap.h"

// Forward declarations.
void eth_init(void);
uint8_t eth_rx(void);
void eth_tx(void);

extern uint16_t eth_inp_len;
extern uint8_t eth_inp[1514];
extern uint16_t eth_outp_len;
extern uint8_t eth_outp[1514];

const uint8_t arpHeader[10]   = {0x08, 0x06, 0x00, 0x01, 0x08, 0x00, 0x06, 0x04, 0x00, 0x01};
const uint8_t myMacAddress[6] = {0x70, 0x4D, 0x7B, 0x11, 0x22, 0x33};  // AsustekC
const uint8_t myIpAddress[4]  = {192, 168, 1, 77};

void processFrame(void)
{
   uint8_t counter = 0;

   printf("Got frame\n");

   // Is it an ARP request?
   if (memcmp(eth_inp+12, arpHeader, 10))
      return;  // No

   printf("Got ARP.\n");

   // Is the request for our IP address?
   if (memcmp(eth_inp+38, myIpAddress, 4))
      return;  // No

   printf("Bingo!\n");

   // Build new MAC header
   memcpy(eth_outp, eth_inp+6, 6);
   memcpy(eth_outp+6, myMacAddress, 6);

   // Build new ARP header
   memcpy(eth_outp+12, arpHeader, 10);
   eth_outp[21] = 2; // ARP Reply
   memcpy(eth_outp+22, myMacAddress, 6);
   memcpy(eth_outp+28, myIpAddress, 4);
   memcpy(eth_outp+32, eth_inp+22, 10); // Copy original senders MAC and IP address to the target.

   memset(eth_outp+42, 0, 18); // Padding
   eth_outp_len = 60;
   eth_tx();
} // end of processFrame

void main(void)
{
   eth_init();

   // Wait for data to be received, and print to the screen
   while (1)
   {
      // Wait until packet is received.
      while (eth_rx())
      {
      }

      processFrame();
   }

} // end of main

