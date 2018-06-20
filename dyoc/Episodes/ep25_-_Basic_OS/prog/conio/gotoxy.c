#include <stdint.h>     // uint8_t, etc.
#include <conio.h>

#include "comp.h"

uint8_t pos_x;
uint8_t pos_y;

void gotoxy(uint8_t x, uint8_t y)
{
   pos_x = x;
   pos_y = y;
} // end of gotoxy


