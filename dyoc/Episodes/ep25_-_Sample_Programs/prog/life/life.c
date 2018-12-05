#include <stdint.h>
#include <stdlib.h>  // rand()
#include <conio.h>
#include <string.h>  // memcpy()
#include <time.h>    // clock()

#define SIZE_X 80
#define SIZE_Y 60

#define ROWS (SIZE_Y+2)
#define COLS (SIZE_X+2)

#define D  (COLS)
#define DR (COLS+1)
#define DL (COLS-1)
#define R  (1)
#define L  (-1)
#define U  (-COLS)
#define UR (-COLS+1)
#define UL (-COLS-1)

const uint8_t PROP = 20;

char    board[ROWS*COLS];
char    color[ROWS*COLS];
char newboard[ROWS*COLS];

void reset(void)
{
   uint8_t x;
   uint8_t y;

   memset(board, 0, sizeof(board));
   memset(color, 0, sizeof(board));
   memset(newboard, 0, sizeof(newboard));

   for (y=1; y<=SIZE_Y; ++y)
   {
      uint16_t iStart = y*COLS;

      for (x=1; x<=SIZE_X; ++x)
      {
         uint16_t idx = iStart+x;

         if ((rand()%100) < PROP)
         {
            board[idx] = 1;
         }
      }
   }
} // end of reset


void update(void)
{
   uint8_t x;
   uint8_t y;

   for (y=1; y<=SIZE_Y; ++y)
   {
      uint16_t iStart = y*COLS;

      for (x=1; x<=SIZE_X; ++x)
      {
         uint16_t idx = iStart+x;

         uint8_t neighbours = 
            (board+D)[idx]  +    // This strange construction is an optimization.
            (board+DR)[idx] +
            (board+DL)[idx] +
            (board+R)[idx]  +
            (board+L)[idx]  +
            (board+U)[idx]  +
            (board+UR)[idx] +
            (board+UL)[idx];

         newboard[idx] = board[idx];
         if (board[idx] && (neighbours < 2 || neighbours > 3))
         {
            // Death
            newboard[idx] = 0;
            color[idx] = 0;
         }
         if (!board[idx] && (neighbours == 3))
         {
            // Birth
            newboard[idx] = 1;
            color[idx] = 1;
         }

         if (board[idx])
         {
            if (color[idx] < 15)
            {
               color[idx] += 1;
            }
         }
      }
   }

   memcpy(board, newboard, sizeof(board));
} // end of update


extern uint8_t* curs_pos;
#pragma zpsym("curs_pos");    // curs_pos is in zero-page.

void show(void)
{
   uint8_t x;
   uint8_t y;

   for (y=1; y<=SIZE_Y; ++y)
   {
      uint16_t iStart = y*COLS;
      uint8_t *p = &board[iStart];

      gotoxy(0, y-1);
      for (x=1; x<=SIZE_X; ++x)
      {
         if (p[x])
         {
            *(curs_pos + 0x2000) = color[iStart+x];
            cputc('*');
         }
         else
         {
            cputc(' ');
         }
      }
   }
} // end of show

uint16_t ms(void)
{
   uint32_t now;

   now = clock();

   return now/1000;
} // end of ms


void main(void)
{
   int16_t tim = 0;
   uint16_t fps10;

   reset();
   while (1)
   {
      show();

      tim = ms()-tim;
      fps10 = 10000/tim;
      gotoxy(72, 59);
      cprintf("FPS: %d.%d", fps10/10, fps10%10);
      tim = ms();


      if (kbhit())
      {
         srand(ms());
         cgetc();
         reset();
      }
      else
      {
         update();
      }
   }
} // end of main

