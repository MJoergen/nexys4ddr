#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

void chlinexy(uint8_t x, uint8_t y, uint8_t length)
{
   gotoxy(x, y);
   chline(length);
}

