// A little program to do some array manipulations. This is just a simple test of the toolchain and the CPU implementation.
// Call first the init() function to initialize.
// After 100 calls to iter() the mem[] array should contain the following:
// 1 7 7 2 1 2 1 2 0 2
// and the idx variable should contain zero.

#include <stdint.h>

#define SIZE 10

uint8_t mem[SIZE];
uint8_t idx;


void iter()
{
   uint8_t k = mem[idx];

   if (k < SIZE)
   {
      mem[k] += 1;
   }
   else
   {
      mem[idx] = 0;
   }

   idx += 1;
   if (idx >= SIZE)
      idx = 0;

} // end of iter


void main()
{
   uint8_t i;

   // Initialize
   for (i=0; i<SIZE; ++i)
      mem[i] = 0;
   idx = 0;


   // Do the calculations
   for (i=0; i<100; ++i)
   {
      iter();
   }


   // Infinite loop
   while(1)
   {}

} // end of main

