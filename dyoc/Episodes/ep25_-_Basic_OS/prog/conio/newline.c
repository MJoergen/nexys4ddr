#include <stdint.h>     // uint8_t, etc.
#include <string.h>
#include <conio.h>

#include "memorymap.h"
#include "comp.h"

void newline(void)
{
   pos_y++;

   // End of screen, so scroll.
   if (pos_y >= V_CHARS)
   {
      // Move screen up one line
      memmove(MEM_CHAR, MEM_CHAR+H_CHARS, H_CHARS*(V_CHARS-1));

      // Clean bottom line
      memset(MEM_CHAR+H_CHARS*(V_CHARS-1), ' ', H_CHARS);

      pos_y = V_CHARS-1;
   }
} // end of newline


