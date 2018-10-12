#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

void cputcxy(uint8_t x, uint8_t y, char ch)
{
   gotoxy(x, y);
   cputc(ch);
} // end of cputcxy

