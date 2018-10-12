#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

#include "memorymap.h"
#include "comp.h"

void cputc(char ch)
{
   if (ch == '\r')         // Carriage return
   {
      pos_x = 0;
      curs_pos = &MEM_CHAR[H_CHARS*pos_y+pos_x];
   }
   else if (ch == '\n')    // Line feed
   {
      newline();
   }
   else
   {
      putchar(ch);
      pos_x++;

      // End of line, just start at next line
      if (pos_x >= H_CHARS)
      {
         pos_x = 0;
         newline();
      }
   }

} // end of cputc

