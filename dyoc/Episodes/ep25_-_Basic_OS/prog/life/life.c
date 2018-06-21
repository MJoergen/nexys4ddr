#include <stdint.h>
#include <stdlib.h>  // rand()
#include <time.h>    // clock()
#include <conio.h>
#include <string.h>  // memcpy
#include "memorymap.h"  // MEM_CHAR

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
char newboard[ROWS*COLS];

uint16_t tim = 0;

void reset(void)
{
   uint8_t x;
   uint8_t y;

   memset(board, 0, sizeof(board));
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
            newboard[idx] = 0;
         }
         if (!board[idx] && (neighbours == 3))
         {
            newboard[idx] = 1;
         }
      }
   }

   memcpy(board, newboard, sizeof(board));
} // end of update


void show(void)
{
   uint8_t x;
   uint8_t y;

   for (y=1; y<=SIZE_Y; ++y)
   {
      uint16_t iStart = y*COLS;
      uint8_t *p = MEM_CHAR + (y-1)*80;

      for (x=1; x<=SIZE_X; ++x)
      {
         uint16_t idx = iStart+x;

         if (board[idx])
         {
            *p = '*';
            p++;
         }
         else
         {
            *p = ' ';
            p++;
         }
      }
   }
} // end of show


void main(void)
{
   reset();
   while (1)
   {
      show();

      tim = clock()-tim;
      gotoxy(70, 50);
      cprintf("%05d", tim);
      tim = clock();

      if (kbhit())
      {
         srand(clock());
         cgetc();
         reset();
      }
      else
      {
         update();
      }
   }
} // end of main

