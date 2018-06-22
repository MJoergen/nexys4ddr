#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

#include "comp.h"

void cclear(uint8_t length)
{
   while (length)
   {
      cputc(' ');
      length--;
   }
} // end of cclear

