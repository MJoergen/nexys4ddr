#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include "memorymap.h"

// Forward declarations.
void eth_init(void);
uint8_t eth_rx(void);

extern uint16_t eth_inp_len;
extern uint8_t eth_inp[1514];

// This is a small demo program that waits in an infinite loop for incoming
// Ethernet frames. It prints the first 16 bytes of each frame.
// The purpose of this program is to test the synchronization between the CPU
// and the Rx DMA.

// This variable is only used during simulation, to test the arbitration
// between CPU and Ethernet while writing to memory.
uint8_t dummy_counter;

// Index variable
uint8_t i;

void main(void)
{
   eth_init();

   // Wait for data to be received, and print to the screen
   while (1)
   {
      // Wait until packet is received.
      while (eth_rx())
      {
         dummy_counter++;
      }

      // Show the pointer locations of the received Ethernet frame.
      printf("%04x:", eth_inp_len);

      // Show the first 34 bytes of the Ethernet frame (14 bytes MAC header and 20 bytes IP header).
      for (i=0; i<34; ++i)
      {
         printf("%02x", eth_inp[i]);
      }
      printf("\n");
   }

} // end of main

