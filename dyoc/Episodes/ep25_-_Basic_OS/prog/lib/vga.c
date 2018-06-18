#include <stdint.h>     // uint8_t, etc.
#include <string.h>
#include <conio.h>
#include "memorymap.h"

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
uint8_t pos_x = 0;
uint8_t pos_y = 0;

void putchar(uint8_t ch);

void clrscr(void)
{
   memset(MEM_CHAR, ' ', H_CHARS*V_CHARS);
   gotoxy(0, 0);
} // end of clrscr


void gotoxy(uint8_t x, uint8_t y)
{
   pos_x = x;
   pos_y = y;
} // end of gotoxy


static void newline(void)
{
   pos_y++;

   // End of screen, so scroll.
   if (pos_y >= V_CHARS)
   {
      // Move screen up one line
      memmove(MEM_CHAR, MEM_CHAR+H_CHARS, H_CHARS*(V_CHARS-1));

      // Clean bottom line
      memset(MEM_CHAR+H_CHARS*(V_CHARS-1), ' ', H_CHARS);

      pos_y = V_CHARS-1;
   }
} // end of newline


void cputc(char ch)
{
   if (ch == '\n')
   {
      pos_x = 0;
      newline();
   }
   else
   {
      putchar(ch);
      pos_x++;

      // End of line, just start at next line
      if (pos_x >= H_CHARS)
      {
         pos_x = 0;
         newline();
      }
   }
} // end of cputc

void cputcxy(uint8_t x, uint8_t y, char ch)
{
   gotoxy(x, y);
   cputc(ch);
} // end of cputcxy


// For now, we just ignore the file descriptor fd.
int write (int fd, const uint8_t* buf, const unsigned count)
{
   unsigned cnt = count;
   (void) fd;                // Hack to avoid warning about unused variable.

   while (cnt--)
   {
      cputc(*buf);
      buf++;
   }

   return count;
} // end of write


void chlinexy(uint8_t x, uint8_t y, uint8_t length)
{
   gotoxy(x, y);
   chline(length);
}


void chline(uint8_t length)
{
   while (length)
   {
      cputc('-');
      length--;
   }
} // end of chline


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


uint8_t textcolor(uint8_t newCol)
{
   uint8_t oldCol = VGA_PALETTE[15];
   VGA_PALETTE[15] = newCol;
   return oldCol;
}


uint8_t bgcolor(uint8_t newCol)
{
   uint8_t oldCol = VGA_PALETTE[0];
   VGA_PALETTE[0] = newCol;
   return oldCol;
}


uint8_t bordercolor(uint8_t newCol)
{
   return newCol;
}


