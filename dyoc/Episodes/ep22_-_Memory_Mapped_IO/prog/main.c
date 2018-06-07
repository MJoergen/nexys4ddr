#include "printf.h"
#include "memorymap.h"

#define PIXELS_X 640
#define PIXELS_Y 480

void main()
{
   uint16_t line;

   // Set text foreground colour
   VGA_PALETTE[15] = 0xE0; // RED

   while (1)
   {
      for (line = 0; line<PIXELS_Y; ++line)
      {
         // Wait until the beginning of the line.
         while (*VGA_PIX_Y != line)
         {}

         // Wait until outside visible screen.
         while (*VGA_PIX_X < PIXELS_X)
         {}

         // Set background colour
         VGA_PALETTE[0] = line;
      }
   }

} // end of main

