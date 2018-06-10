// This program searches iteratively for a solution to the 8-queens problem on
// a chess board.
// The expected number of solutions is 92.
// See https://en.wikipedia.org/wiki/Eight_queens_puzzle

#include <stdint.h>

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
   }

} // end of calculate_valid

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
      }

      if (q<0)
      {
         break; // out of while loop
      }

   } // end of while (1)

   __asm__("LDA %v", solutions);
loop:
   __asm__("JMP %g", loop);

   return 0;
} // end of main

