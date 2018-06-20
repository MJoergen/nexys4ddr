#include <stdint.h>     // uint8_t, etc.
#include <string.h>
#include <conio.h>

#include "memorymap.h"
#include "comp.h"

void newline(void)
{
   pos_y++;

   // End of screen, restart from top.
   if (pos_y >= V_CHARS)
   {
      pos_y = 0;
   }
} // end of newline


