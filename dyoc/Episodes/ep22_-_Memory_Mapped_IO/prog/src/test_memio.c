// This program tests incrementing the memio block.
// In the test the VGA background colour is used. The program
// compiles to a single instruction: INC $7FC0. Since the
// increment instruction performs a read and a write in the same
// cycle, care must be taken when accessing memio, where there
// is an additional wait cycle.

#include "memorymap.h"  // VGA_PALETTE

int main()
{

   while (1)
   {
      (*VGA_PALETTE) += 1;
   }

   return 0;
} // end of main

