#include "printf.h"
#include "memorymap.h"

#define PIXELS_X 640
#define PIXELS_Y 480

void main()
{
   uint16_t line;

   *VGA_OVERL_FG_COL = 0xE0; // RED

   while (1)
   {
      for (line = 0; line<PIXELS_Y; ++line)
      {
         while (*VGA_PIX_Y_HIGH != line / 256)
         {}

         while (*VGA_PIX_Y_LOW != line & 255)
         {}

         // Wait until the end of the line
         while (*VGA_PIX_X_HIGH < PIXELS_X / 256)
         {}

         while (*VGA_PIX_X_LOW < PIXELS_X & 255)
         {}

         (*VGA_CHAR_BG_COL) = (line / 256);
      }
   }

} // end of main

