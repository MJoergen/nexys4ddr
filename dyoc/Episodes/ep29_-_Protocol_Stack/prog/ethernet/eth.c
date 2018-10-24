#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "memorymap.h"
#include "eth.h"
#include "mac.h"

// When called, this function processes the data received from the Ethernet Rx DMA.
// The first two bytes contain the total number of bytes (including these two bytes).
// The remainding bytes contain the Ethernet frame.
// This function will simply decode the length of the frame and call mac_rx.
void eth_rx(uint8_t *ptr)
{
   uint16_t length = *((uint16_t *)ptr);  // Read as little-endian.

   mac_rx(ptr+2, length-2);
} // end of eth_rx


// This is used when sending an Ethernet frame.
// ptr points to the start of the Ethernet frame, i.e. first byte of the MAC header.
// length contains number of bytes in the Ethernet frame, excl CRC.
// Note: This function assumes there are 2 spare bytes before 'ptr'.
void eth_tx(uint8_t *ptr, uint16_t length)
{
   uint8_t *pkt = ptr - 2;

   // Minimum frame size is 60 bytes excl CRC.
   if (length < 60)
   {
      memset(ptr+length, 0, 60-length); // Make sure padding bytes are cleared.
      length = 60;
   }

   // Insert header with length
   *((uint16_t *)pkt) = length + 2;

   assert (MEMIO_CONFIG->ethTxdmaEnable == 0);

   // Send frame
   MEMIO_CONFIG->ethTxdmaPtr    = (uint16_t) pkt;
   MEMIO_CONFIG->ethTxdmaEnable = 1;

   // Wait until frame has been consumed by TxDMA.
   while (MEMIO_CONFIG->ethTxdmaEnable == 1)
   {}

   assert (MEMIO_CONFIG->ethTxdmaEnable == 0);

} // end of eth_tx

