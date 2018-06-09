#include <stdint.h>     // uint8_t, etc.
#include "memorymap.h"  // MEM_CHAR

// This is just a very simple implementation of the write() function.
// The only control character it supports is newline.

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
static uint8_t x = 0;
static uint8_t y = 0;

// For now, we just ignore the file descriptor fd.
int write (int fd, const uint8_t* buf, const unsigned count)
{
   unsigned cnt = count;
   (void) fd;                // Hack to avoid warning about unused variable.

   while (cnt--)
   {
      uint8_t ch = *(buf++);
      switch (ch)
      {
         case '\n' :    // Newline
            x = 0;
            y++;
            break;

         default:       // Any other character is considered a regular character.
            MEM_CHAR[H_CHARS*y+x] = ch;
            x++;
            break;
      } // end of switch

      // End of line, just start at next line
      if (x >= H_CHARS)
      {
         x = 0;
         y++;
      }

      // End of screen, just go back to the top.
      if (y >= V_CHARS)
      {
         x = 0;
         y = 0;
      }
   }

   return count;
} // end of write

