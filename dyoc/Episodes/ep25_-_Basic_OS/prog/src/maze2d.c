#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>     // rand()
#include <time.h>       // clock()
#include <conio.h>

#define MAX_ROWS	11
#define MAX_COLS  24
#define MAX_SQUARES	(MAX_ROWS*MAX_COLS)

uint8_t grid[MAX_SQUARES];

#define GetRow(sq)	(sq % MAX_ROWS)
#define GetCol(sq)	(sq / MAX_ROWS)

enum
{
   DIR_NORTH = 0,
   DIR_EAST,
   DIR_WEST,
   DIR_SOUTH,
   MAX_DIRS
};
const int offset[MAX_DIRS] = {-1, MAX_ROWS, -MAX_ROWS, 1};

uint8_t GetRandomDir()
{
   return rand() % MAX_DIRS;
}

uint16_t GetRandomSquare()
{
   return rand() % MAX_SQUARES;
}

void InitMaze(void)
{
   int sq;
   int count;

   for(sq=0; sq<MAX_SQUARES; sq++)
   {
      grid[sq]=0;
   }

   sq = GetRandomSquare();
   count = MAX_SQUARES-1;
   while (count)
   {
      int dir = GetRandomDir();
      int newSq = sq + offset[dir];

      if ( ((GetRow(sq)==GetRow(newSq)) + (GetCol(sq)==GetCol(newSq)) == 1)
            && (newSq>=0) && (newSq<MAX_SQUARES) )
      {
         if (!grid[newSq])
         {	/* We haven't been here before. */

            /* Make an opening */
            grid[sq] += 1 << (dir);
            sq = newSq;
            grid[sq] += 1 << ((MAX_DIRS-1) - dir);
            count--;
         }
         else if (abs(rand()) < abs(rand())/6)
         {
            do
            {
               sq = GetRandomSquare();
            }
            while (!grid[sq]);
         }
      }
   }
} // end of InitMaze

int main()
{
   int curSq, printSq;

   srand(clock());

   InitMaze();

   clrscr();

   /* Get random start square */
   curSq = MAX_SQUARES - 1;

   while (curSq >= 0)
   {
      int dir;

#define BEEN_HERE 1<<7

      cputsxy(1, 1, "You escaped!");

      grid[curSq] |= BEEN_HERE;

      for (printSq=0; printSq<MAX_SQUARES; printSq++)
      {
         if (grid[printSq] & BEEN_HERE)
         {
            const char wall = '#';
            int col = 1 + 2*GetCol(printSq);
            int row = 1 + 2*GetRow(printSq);
            int g = grid[printSq];

            cputcxy(row+1, col+1, ' ');
            cputcxy(row,   col,   wall);
            cputcxy(row+2, col,   wall);
            cputcxy(row+2, col+2, wall);
            cputcxy(row,   col+2, wall);
            cputcxy(row,   col+1, (g&(1<<DIR_NORTH)) ? ' ' : wall);
            cputcxy(row+1, col+2, (g&(1<<DIR_EAST))  ? ' ' : wall);
            cputcxy(row+1, col,   (g&(1<<DIR_WEST))  ? ' ' : wall);
            cputcxy(row+2, col+1, (g&(1<<DIR_SOUTH)) ? ' ' : wall);
         }
      }
      cputcxy(2+GetRow(curSq)*2, 2+GetCol(curSq)*2, curSq ? '@' : '*');
      gotoxy(2+GetRow(curSq)*2, 2+GetCol(curSq)*2);

      dir = MAX_DIRS;
      switch (cgetc())
      {
         case 'w': case 'k': dir = DIR_NORTH; break;
         case 's': case 'j': dir = DIR_SOUTH; break;
         case 'd': case 'l': dir = DIR_EAST; break;
         case 'a': case 'h': dir = DIR_WEST; break;
         case 'q': curSq = -1; break;
      }

      if (dir < MAX_DIRS)
      {
         if (grid[curSq] & (1<<dir))
         {
            curSq += offset[dir];
         }
      }
   } // end of while (curSq >= 0)

   return 0;
} // end of main

