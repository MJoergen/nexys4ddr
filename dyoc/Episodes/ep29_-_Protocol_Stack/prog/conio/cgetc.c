#include <6502.h>                // SEI() and CLI()
#include <string.h>              // memmove
#include "memorymap.h"

extern uint8_t  kbd_buffer_count;
extern uint8_t  kbd_buffer[];

// This does a BLOCKING wait, until a keyboard event is present in the buffer
// It will pop this value and return.
uint8_t cgetc(void)
{
   uint8_t kbd_data;

   // Do a BLOCKING wait for keyboard event.
   // The variable kbd_buffer_count will be incremented by the interrupt
   // service routine in lib/kbd_isr.s.
   while (kbd_buffer_count == 0)
   {} // Do nothing while waiting.


   // Use SEI() and CLI() as a primitive semaphore to prevent the
   // interrupt service routine from accessing the buffer
   // while we're updating it here.
   SEI();
   kbd_data = kbd_buffer[0];  // Read first entry from buffer
   memmove(kbd_buffer, kbd_buffer+1, kbd_buffer_count);  // Take entry out of buffer
   kbd_buffer_count--;
   CLI();

   return kbd_data;
} // end of cgetc


