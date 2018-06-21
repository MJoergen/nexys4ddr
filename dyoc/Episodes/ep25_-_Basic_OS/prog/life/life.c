#include <stdint.h>
#include <stdlib.h>  // rand()
#include <time.h>    // clock()
#include <conio.h>
#include <string.h>  // memcpy

#define SIZE_X 80
#define SIZE_Y 60

const uint8_t PROP = 10;

char    board[SIZE_Y+2][SIZE_X+2];
char newboard[SIZE_Y+2][SIZE_X+2];


void reset(void)
{
   uint8_t x;
   uint8_t y;

   for (y=0; y<SIZE_Y+2; ++y)
   {
      for (x=0; x<SIZE_X+2; ++x)
      {
         if ((rand()%100) < PROP)
         {
            board[y][x] = 1;
         }
         else
         {
            board[y][x] = 0;
         }

         if (x==0 || x==SIZE_X+1 || y==0 || y==SIZE_Y+1)
         {
            board[y][x] = 0;
            newboard[y][x] = 0;
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
      for (x=1; x<=SIZE_X; ++x)
      {
         uint8_t neighbours = 
            board[y-1][x-1] +
            board[y-1][x] +
            board[y-1][x+1] +
            board[y][x-1] +
            board[y][x+1] +
            board[y+1][x-1] +
            board[y+1][x] +
            board[y+1][x+1];

         newboard[y][x] = board[y][x];
         if (board[y][x] && (neighbours < 2 || neighbours > 3))
         {
            newboard[y][x] = 0;
         }
         if (!board[y][x] && (neighbours == 3))
         {
            newboard[y][x] = 1;
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
      for (x=1; x<=SIZE_X; ++x)
      {
         if (board[y][x])
         {
            cputcxy(x-1, y-1, '*');
         }
         else
         {
            cputcxy(x-1, y-1, ' ');
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

