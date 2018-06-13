#include <6502.h>                // SEI() and CLI()
#include <string.h>              // memmove
#include "memorymap.h"

#define KBD_BUFFER_SIZE 10       // This should just be a small numer.

//////////////////////////////////////////////////////////////////////////////////
// Don't change these declarations, because they are used in the interrupt
// service routine lib/kbd_irq.s
const uint8_t kbd_buffer_size = KBD_BUFFER_SIZE;   // Make sure it is declared
                                                   // as a const, so it will
                                                   // reside in ROM. This
                                                   // prevents it from
                                                   // accidentally getting
                                                   // corrupted.
uint8_t kbd_buffer[KBD_BUFFER_SIZE];
uint8_t kbd_buffer_count = 0;
//////////////////////////////////////////////////////////////////////////////////


// This does a BLOCKING wait, until a keyboard event is present in the buffer
// It will pop this value and return.
uint8_t getch()
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
} // end of getch


