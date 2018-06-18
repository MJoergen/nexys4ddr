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

void cputsxy (uint8_t x, uint8_t y, const uint8_t* s)
{
   gotoxy(x, y);
   cputs(s);
}
