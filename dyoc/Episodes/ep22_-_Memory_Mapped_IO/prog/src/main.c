// This program searches iteratively for a solution to the 8-queens problem on
// a chess board.
// The expected number of solutions is 92.
// See https://en.wikipedia.org/wiki/Eight_queens_puzzle
//
// It prints out all the solutions.
//
// At the same time, it attempts to maintain a visual pattern synchronous with the
// VGA output.

#include <stdint.h>
#include <stdio.h>
#include "memorymap.h"

#define SIZE 8

uint8_t  pos[SIZE];
uint8_t  valid[SIZE];
uint8_t  solutions = 0;
uint16_t iterations = 0;

static void calculate_valid(void)
{
   uint8_t val=1;
   uint8_t q;
   uint8_t c;
   for (q=1; q<SIZE; ++q)
   {
      if (val) // This is just an optimization
      {
         for (c=0; c<q; ++c)
         {
            val = val && (pos[c]         != pos[q]) &&
                         (pos[c] + (q-c) != pos[q]) &&
                         (pos[c]         != pos[q] + (q-c));
         }
      }
      valid[q] = val;

      // Set background colour equal to the current line number.
      VGA_PALETTE[0] = *VGA_PIX_Y;
   }

} // end of calculate_valid

static void print_all(void)
{
   uint8_t q;

   for (q=0; q<SIZE; ++q)
   {
      printf("%d ", pos[q]);

      // Set background colour equal to the current line number.
      VGA_PALETTE[0] = *VGA_PIX_Y;
   }
   printf("\n");
} // end of print_all

int main()
{
   int8_t q;   // Must be a signed type

   for (q=0; q<SIZE; ++q)
   {
      pos[q] = 0;
      valid[q] = 1;
   }

   while (1)
   {
      iterations++;

      calculate_valid();
      if (valid[SIZE-1])
      {
         solutions++;
         print_all();
      }

      for (q=SIZE-1; q>=0; --q)
      {
         uint8_t val = (q==0) || (valid[q-1]);
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

