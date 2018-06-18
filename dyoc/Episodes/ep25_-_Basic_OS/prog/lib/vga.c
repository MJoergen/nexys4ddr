#include <stdint.h>     // uint8_t, etc.
#include <string.h>
#include <conio.h>
#include "memorymap.h"

// Screen size in number of characters
#define H_CHARS 80   // Horizontal
#define V_CHARS 60   // Vertical

// Current cursor position
static uint8_t pos_x = 0;
static uint8_t pos_y = 0;

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


void putchar(uint8_t ch)
{
   MEM_CHAR[H_CHARS*pos_y+pos_x] = ch;
}


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


void screensize(uint8_t* x, uint8_t* y)
{
   *x = H_CHARS;
   *y = V_CHARS;
}

extern uint8_t  curs_enable;
extern uint8_t* curs_pos;
extern uint8_t  curs_inverted;
extern uint8_t  curs_cnt;

#pragma zpsym("curs_pos");    // curs_pos is in zero-page.

static uint8_t nibble_swap(uint8_t val)
{
   return (val << 4) | (val >> 4);
}


uint8_t cursor(uint8_t onoff)
{
   uint8_t oldOnOff = curs_enable;

   curs_enable = 0;  // Make sure a stray interrupt doesn't cause a crash.

   if (onoff == 0)
   {
      curs_pos      = &MEM_CHAR[H_CHARS*pos_y+pos_x];
      curs_inverted = 0;
      curs_cnt      = 2;     // Give it a low value, so that it will quickly invert.
      curs_enable   = onoff;
   }
   else
   {
      if (curs_inverted)
      {
         *curs_pos = nibble_swap(*curs_pos);
      }
   }

   return oldOnOff;
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


