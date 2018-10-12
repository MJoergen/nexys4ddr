#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

void cputs (const uint8_t* s)
{
   while (*s)
   {
      cputc(*s);
      s++;
   }
}

