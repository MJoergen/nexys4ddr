#include <string.h>     // memmove() and memset()
#include <stdint.h>     // uint8_t, etc.
#include "memorymap.h"  // Defines MEM_CHAR
#include "printf.h"

// Simple implementation of printf. Only supports printing text strings.
// A newline will jump to the beginning of the next line.

void printf(char* str)
{
   static uint8_t* CharMemory = MEM_CHAR;

   // Current position of cursor
   static uint8_t x=0, y=0;

   int i;

   for (i = 0; str[i] != '\0'; ++i)
   {
      switch (str[i])
      {
         case '\n':
            x = 0;
            y++;
            break;

         default:
            CharMemory[SCREEN_X*y+x] = str[i];
            x++;
            break;
      } // end of switch

      if (x >= SCREEN_X)
      {
         x = 0;
         y++;
      }

      if (y >= SCREEN_Y)
      {
         // Move screen up one line
         memmove(CharMemory,                 // destination is start of first line.
                 CharMemory + SCREEN_X,      // source is start of second line.
                 SCREEN_X*(SCREEN_Y-1));     // length is screen minus one line.

         // Clear bottom line
         memset(CharMemory + SCREEN_X*(SCREEN_Y-1),   // destination is start of last line.
                ' ',                                  // character is space.
                SCREEN_X);                            // size if one line.

         y = SCREEN_Y-1;
         x = 0;
      }
   } // end of for
} // end of printf

// Print an 8-bit hexadecimal number
void printfHex8(uint8_t key)
{
    char foo[3] = "00";
    char* hex = "0123456789ABCDEF";
    foo[0] = hex[(key >> 4) & 0xF];
    foo[1] = hex[key & 0xF];
    printf(foo);
} // end of printfHex8

// Print a 16-bit hexadecimal number
void printfHex16(uint16_t key)
{
    printfHex8((key >> 8) & 0xFF);
    printfHex8( key & 0xFF);
} // end of printfHex16

