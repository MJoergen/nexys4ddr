#include <stdint.h>     // uint8_t, etc.
#include <conio.h>


void chline(uint8_t length)
{
   while (length)
   {
      cputc('-');
      length--;
   }
} // end of chline


