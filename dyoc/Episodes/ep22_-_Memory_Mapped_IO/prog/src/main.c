// This program searches iteratively for a solution to the 8-queens problem on
// a chess board.
// The expected number of solutions is 92.
// See https://en.wikipedia.org/wiki/Eight_queens_puzzle
//
// At the same time, it attempts to maintain a visual pattern synchronous with the
// VGA output.

#include <stdio.h>
#include "memorymap.h"

#define H_PIXELS 640
#define V_PIXELS 480

#define SIZE 8

static void calculate_valid(int *valid, const int *pos)
{
   int val=1;
   int q;
   int c;
   for (q=1; q<SIZE; ++q)
   {
      if (val) // This is just an optimization
      {
         for (c=0; c<q; ++c)
         {
            val = val && (pos[c] != pos[q]) &&
               (pos[c] + (q-c) != pos[q]) &&
               (pos[c] != pos[q] + (q-c));
         }
      }
      valid[q] = val;

      // Set background colour equal to the current line number.
      VGA_PALETTE[0] = *VGA_PIX_Y;
   }

} // end of calculate_valid

static void print_all(const int *p)
{
   int q;

   for (q=0; q<SIZE; ++q)
   {
      printf("%d ", p[q]);

      // Set background colour equal to the current line number.
      VGA_PALETTE[0] = *VGA_PIX_Y;
   }
   printf("\n");
} // end of print_all

int main()
{
   int pos[SIZE];
   int valid[SIZE];
   int q;
   int solutions = 0;
   int iterations = 0;

   for (q=0; q<SIZE; ++q)
   {
      pos[q] = 0;
      valid[q] = 1;
   }

   while (1)
   {
      iterations++;

      calculate_valid(valid, pos);
      if (valid[SIZE-1])
      {
         solutions++;
         print_all(pos);
      }

      for (q=SIZE-1; q>=0; --q)
      {
         int val = (q==0) || (valid[q-1]);
         if (val && (pos[q]<SIZE-1))
         {
            pos[q]++;
            break; // out of for loop
         }
         pos[q] = 0;

         // Set background colour equal to the current line number.
         VGA_PALETTE[0] = *VGA_PIX_Y;
      }

      if (q<0)
      {
         break; // out of while loop
      }

      // Set background colour equal to the current line number.
      VGA_PALETTE[0] = *VGA_PIX_Y;
   } // end of while (1)

   printf("%d iterations.\n", iterations);
   printf("%d solutions.\n", solutions);

   while (1)
   {
      // Set background colour equal to the current line number.
      VGA_PALETTE[0] = *VGA_PIX_Y;
   }

   return 0;
} // end of main

