#include "printf.h"
#include "memorymap.h"

#define H_PIXELS 640
#define V_PIXELS 480

void main()
{
   uint16_t line;
   uint8_t i;

   for (i=0; i<70; ++i)
   {
      printf("Hello World: ");
      printfHex8(i);
      printf("\n");
   }

   // Set text foreground colour
   VGA_PALETTE[15] = 0xE0; // RED

   while (1)
   {
      for (line = 0; line<V_PIXELS; ++line)
      {
         // Wait until the beginning of the line.
         while (*VGA_PIX_Y != line)
         {}

         // Wait until outside visible screen.
         while (*VGA_PIX_X < H_PIXELS)
         {}

         // Set background colour
         VGA_PALETTE[0] = line;
      }
   }

} // end of main

