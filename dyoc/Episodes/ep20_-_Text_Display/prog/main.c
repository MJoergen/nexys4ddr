#include "printf.h"

void main()
{
   uint8_t i;
   for (i=0; i<70; ++i)
   {
      printf("Hello World: ");
      printfHex8(i);
      printf("\n");
   }
} // end of main

