#include <stdint.h>
#include <stdlib.h>     // rand()
#include <time.h>       // clock()
#include <conio.h>

#define MAX_ROWS  28
#define MAX_COLS  28
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


void DrawPos(uint16_t sq)
{
   const char wall = '#';
   uint8_t col = 1 + 2*GetCol(sq);
   uint8_t row = 1 + 2*GetRow(sq);
   uint8_t g = grid[sq];

   cputcxy(col+1, row+1, ' ');
   cputcxy(col,   row,   wall);
   cputcxy(col,   row+2, wall);
   cputcxy(col+2, row+2, wall);
   cputcxy(col+2, row,   wall);
   cputcxy(col+1, row,   (g&(1<<DIR_NORTH)) ? ' ' : wall);
   cputcxy(col+2, row+1, (g&(1<<DIR_EAST))  ? ' ' : wall);
   cputcxy(col,   row+1, (g&(1<<DIR_WEST))  ? ' ' : wall);
   cputcxy(col+1, row+2, (g&(1<<DIR_SOUTH)) ? ' ' : wall);
} // end of DrawPos


void InitMaze(void)
{
   int sq;
   int count;
   uint16_t c;

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
            grid[sq] += 1 << (dir); DrawPos(sq);
            sq = newSq;
            grid[sq] += 1 << ((MAX_DIRS-1) - dir); DrawPos(sq);
            count--;
            gotoxy(70, 10); cprintf("%05d", count);
            for (c=0; c<10000; ++c)
            {
            }
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

      if (!curSq)
      {
         cputsxy(1, 58, "You escaped!");
      }

      grid[curSq] |= BEEN_HERE;

      for (printSq=0; printSq<MAX_SQUARES; printSq++)
      {
         if (grid[printSq] & BEEN_HERE)
         {
            DrawPos(printSq);
         }
      }
      cputcxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2, curSq ? '@' : '*');
      gotoxy(2+GetCol(curSq)*2, 2+GetRow(curSq)*2);

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

