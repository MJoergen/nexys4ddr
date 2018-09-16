#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

#include "comp.h"

void cvline(uint8_t length)
{
   while (length)
   {
      putchar('|');
      newline();
      length--;
   }
}


