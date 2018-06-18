#include <stdio.h>
#include <stdint.h>
#include <conio.h>

void newline(void);

void cvline(uint8_t length)
{
   while (length)
   {
      putchar('|');
      newline();
   }
}

void cvlinexy(uint8_t x, uint8_t y, uint8_t length)
{
   gotoxy(x, y);
   cvline(length);
}

