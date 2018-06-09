#include <stdio.h>
#include <stdint.h>

void main()
{
   uint8_t i;
   for (i=0; i<70; ++i)
   {
      printf("Hello World: %02x\n", i);
   }
} // end of main

