#include "types.h"
#include "memorymap.h" // Defines MAP_CHAR

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
            CharMemory[80*y+x] = str[i];
            x++;
            break;
      } // end of switch

      if (x >= 80)
      {
         x = 0;
         y++;
      }

      if (y >= 25)
      {
         for (y = 0; y < 25; y++)
            for (x = 0; x < 80; x++)
               CharMemory[80*y+x] = ' ';
         x = 0;
         y = 0;
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
} // end of printfHex

// Print a 16-bit hexadecimal number
void printfHex16(uint16_t key)
{
    printfHex8((key >> 8) & 0xFF);
    printfHex8(key & 0xFF);
} // end of printfHex16

