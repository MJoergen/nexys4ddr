#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

#include "comp.h"

void cclearxy(uint8_t x, uint8_t y, uint8_t length)
{
   gotoxy(x, y);
   cclear(length);
} // end of cclearxy

