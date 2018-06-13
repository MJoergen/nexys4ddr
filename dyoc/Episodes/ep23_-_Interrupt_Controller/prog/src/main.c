// This program searches iteratively for a solution to the 8-queens problem on
// a chess board.
// The expected number of solutions is 92.
// See https://en.wikipedia.org/wiki/Eight_queens_puzzle
//
// It measures the time taken to find all the solutions.
//
// At the same time, it maintains a visual pattern synchronous with the
// VGA output, using interrupts.

#define __ATMOS__       // Set the correct value (100) for CLOCKS_PER_SEC

#include <stdint.h>
#include <stdio.h>
#include <time.h>
#include "sys_irq.h"    // sys_set_vga_irq

extern t_irq_handler vga_isr;

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
            val = val && (pos[c] != pos[q]) &&
               (pos[c] + (q-c) != pos[q]) &&
               (pos[c] != pos[q] + (q-c));
         }
      }
      valid[q] = val;
   }

} // end of calculate_valid

static void print_all(void)
{
   uint8_t q;

   for (q=0; q<SIZE; ++q)
   {
      printf("%d ", pos[q]);
   }
   printf("\n");
} // end of print_all

int main()
{
   int8_t q;   // Must be a signed type
   clock_t t1;
   clock_t t2;
   clock_t diff;
   clock_t secs;
   clock_t hunds;

   for (q=0; q<SIZE; ++q)
   {
      pos[q] = 0;
      valid[q] = 1;
   }

   // Enable VGA interupts
   sys_set_vga_irq(&vga_isr);

   t1 = clock();
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
      }

      if (q<0)
      {
         break; // out of while loop
      }
   } // end of while (1)
   t2 = clock();

   printf("%d iterations.\n", iterations);
   printf("%d solutions.\n", solutions);
   diff = t2-t1;
   secs = diff / CLOCKS_PER_SEC;
   hunds = ((diff - secs*CLOCKS_PER_SEC)*100) / CLOCKS_PER_SEC;
   printf("%ld.%02ld seconds.\n", secs, hunds);

   // End with a busy loop to prevent interrupts from being disabled.
   while (1)
   {}

   return 0;
} // end of main

